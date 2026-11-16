#if DEBUG || BETA
import Foundation
import Observation

/// 設定のバックアップの欄（#161、ADR 0058・0059）。オン・オフ、最後のバックアップ、最後の失敗、「今すぐバックアップ」、
/// ほかの端末の控えとの食い違いの確認、オフにしたときに消せなかった控えの消し直し、空の端末への取り込み（ADR 0061）を扱う。
/// 状態は Repository が端末に置いたものを、操作のたびに読み直して写す。
@MainActor
@Observable
final class BackupSectionViewModel {
	/// オフにする前の確認に出す、サーバーの控えの件数。
	enum DisableConfirmation: Equatable {
		case remote(sessionCount: Int)
		case noRemote
		case unknown
	}

	/// 動いている処理。押したボタンの行に進み具合を出すため。
	enum Activity: Equatable {
		case backingUp
		case replacing
		case disabling
		case deletingRemote
		case restoring
	}

	private let backupRepository: any BackupRepositoryProtocol
	/// 401 で端末のトークンとバックアップの状態が消えたときに呼ぶ。アカウントの欄を読み直すため。
	@ObservationIgnored private let onSignInRequired: () -> Void
	/// 端末にサインインのトークンがあるか。ないときは、取り込める控えをサーバーに問い合わせない。
	@ObservationIgnored private let isSignedIn: () -> Bool
	/// サインインの直後に `true` にし、次に読み終えた取り込める控えを ``restorePrompt`` に入れる。
	@ObservationIgnored private var isOfferingRestore = false
	@ObservationIgnored private var loadGeneration = 0

	private(set) var status: BackupStatus
	/// 「確認が要る」のときに読んだ件数。置き換えるときは、この版を条件にする。
	private(set) var conflict: BackupConflict?
	private(set) var disableConfirmation: DisableConfirmation?
	private(set) var activity: Activity?
	/// 同意してから最初の送信が終わるまで `true`。その間も切り替えをオンに見せる。
	private(set) var isEnabling = false
	/// 端末の状態に置かれない失敗（件数を読めなかった、など）。
	private(set) var errorMessage: String?
	/// 「今すぐバックアップ」で送り終えたか、前回と同じ中身で送らずに済んだときに `true`。
	/// 押した反応を見せるため、次の操作か読み直しまで「最新の状態です」を出す。
	private(set) var isUpToDate = false
	/// 端末に曲も記録もなく、サーバーに控えがあるときの件数と日時。取り込みの行を出すため。
	private(set) var restorable: BackupRestorableSummary?
	/// サインインの直後に、取り込むかを聞く控え。聞いている間だけ入る。
	private(set) var restorePrompt: BackupRestorableSummary?
	/// 取り込み終えた記録の件数。次の操作か読み直しまで出す。
	private(set) var restoredSessionCount: Int?

	init(
		backupRepository: any BackupRepositoryProtocol,
		isSignedIn: @escaping () -> Bool = { true },
		onSignInRequired: @escaping () -> Void = {}
	) {
		self.backupRepository = backupRepository
		self.isSignedIn = isSignedIn
		self.onSignInRequired = onSignInRequired
		status = backupRepository.status
	}

	var isWorking: Bool {
		activity != nil
	}

	var isOn: Bool {
		status.isActive || isEnabling
	}

	var lastSucceededAt: Date? {
		status.lastSucceededAt
	}

	/// 出す失敗は 1 つにする。最後の失敗と同じ理由を 2 回出さないため。
	var failureMessage: String? {
		errorMessage ?? status.lastFailure.map(Self.message(for:))
	}

	var conflictMessage: String? {
		conflict.map { "サーバーの \($0.serverSessionCount) 件を、この端末の \($0.localSessionCount) 件で置き換えます" }
	}

	var canRetryRemoteDeletion: Bool {
		status.lastFailure == .remoteDeletionFailed
	}

	var disableConfirmationMessage: String? {
		switch disableConfirmation {
		case .remote(let sessionCount):
			"サーバーにあるバックアップ（\(sessionCount) 件）を消します。この iPhone の記録は消えません。"
		case .noRemote:
			"サーバーにバックアップはありません。この iPhone の記録は消えません。"
		case .unknown:
			"サーバーのバックアップの件数を読めませんでした。オフにすると、サーバーのバックアップを消します。この iPhone の記録は消えません。"
		case nil:
			nil
		}
	}

	func load() async {
		isUpToDate = false
		restoredSessionCount = nil
		await refresh()
	}

	/// 本人がサインインし終えたときに呼ぶ。取り込める控えがあれば ``restorePrompt`` に入れて聞く（ADR 0061）。
	func offerRestoreAfterSignIn() async {
		isOfferingRestore = true
		await load()
	}

	func cancelRestorePrompt() {
		restorePrompt = nil
	}

	/// サーバーの控えを、空の端末に取り込む。取り込めたら件数を ``restoredSessionCount`` に入れ、取り込みの行を消す。
	func restore() async {
		restorePrompt = nil
		guard !isWorking else { return }
		activity = .restoring
		isUpToDate = false
		restoredSessionCount = nil
		defer { activity = nil }
		var restoredCount: Int?
		var thrown: BackupRestoreFailure?
		do {
			restoredCount = try await backupRepository.restoreAll()
		} catch {
			thrown = error as? BackupRestoreFailure ?? .server
		}
		if thrown == .signInRequired {
			onSignInRequired()
		}
		await refresh()
		restoredSessionCount = restoredCount
		if let thrown, thrown != .signInRequired {
			errorMessage = Self.restoreMessage(for: thrown)
		}
	}

	/// 同意の画面の「オンにする」。送るのに失敗してもオンのままになるので、結果はこの欄に出す。
	func enable() async {
		await perform(.backingUp, isEnabling: true) { _ = try await $0.enable() }
	}

	func backUpNow() async {
		var outcome: BackupOutcome?
		await perform(.backingUp) { outcome = try await $0.backUp(trigger: .manual) }
		isUpToDate = outcome == .uploaded || outcome == .unchanged
	}

	func confirmReplace() async {
		guard let conflict else { return }
		await perform(.replacing) { _ = try await $0.replaceRemote(confirmed: conflict) }
	}

	func prepareDisable() async {
		guard !isWorking else { return }
		activity = .disabling
		isUpToDate = false
		errorMessage = nil
		defer { activity = nil }
		do {
			disableConfirmation = if let count = try await backupRepository.fetchRemoteSessionCount() {
				.remote(sessionCount: count)
			} else {
				.noRemote
			}
		} catch BackupFailure.signInRequired {
			onSignInRequired()
			await refresh()
		} catch {
			disableConfirmation = .unknown
		}
	}

	func cancelDisable() {
		disableConfirmation = nil
	}

	func disable() async {
		disableConfirmation = nil
		await perform(.disabling) { try await $0.disable() }
	}

	func retryRemoteDeletion() async {
		await perform(.deletingRemote) { try await $0.retryRemoteDeletion() }
	}

	private func perform(_ activity: Activity, isEnabling: Bool = false, _ operation: (any BackupRepositoryProtocol) async throws -> Void) async {
		guard !isWorking else { return }
		self.activity = activity
		self.isEnabling = isEnabling
		isUpToDate = false
		restoredSessionCount = nil
		defer {
			self.activity = nil
			self.isEnabling = false
		}
		var thrown: BackupFailure?
		do {
			try await operation(backupRepository)
		} catch {
			thrown = error as? BackupFailure ?? .server
		}
		if thrown == .signInRequired {
			onSignInRequired()
		}
		await refresh()
		if let thrown, thrown != .signInRequired, thrown != status.lastFailure {
			errorMessage = Self.message(for: thrown)
		}
	}

	/// 端末の状態を写し、「確認が要る」なら件数を読み、続けて取り込める控えを読む。
	/// 読んだ結果と、読めなかった文は、この読み込みが最新のときだけ書く。読み終えたときに新しい読み込みが始まっていたら、何も書かない。
	private func refresh() async {
		loadGeneration += 1
		let generation = loadGeneration
		status = backupRepository.status
		guard await refreshConflict(generation: generation) else { return }
		await refreshRestorable(generation: generation)
	}

	/// 「確認が要る」なら件数を読む。新しい読み込みが始まっていたときと、401 で状態が消えたときは `false` を返す。
	private func refreshConflict(generation: Int) async -> Bool {
		guard status.lastFailure == .needsConfirmation else {
			conflict = nil
			errorMessage = nil
			return true
		}
		do {
			let conflict = try await backupRepository.fetchConflict()
			guard generation == loadGeneration else { return false }
			self.conflict = conflict
			errorMessage = nil
		} catch {
			guard generation == loadGeneration else { return false }
			conflict = nil
			if error as? BackupFailure == .signInRequired {
				signInWasRequired()
				return false
			}
			errorMessage = "サーバーのバックアップの件数を読めませんでした。時間をおいてもう一度お試しください"
		}
		return true
	}

	/// 端末が空なら、取り込める控えを読む。サインインの直後なら、読めた控えを ``restorePrompt`` に入れる。
	/// 読めなかったときは、前に読めた控えの行を残す（取り込みに失敗した後も、もう一度押せるように）。
	private func refreshRestorable(generation: Int) async {
		guard isSignedIn() else {
			restorable = nil
			isOfferingRestore = false
			return
		}
		do {
			let restorable = try await backupRepository.fetchRestorableBackup()
			guard generation == loadGeneration else { return }
			self.restorable = restorable
			if isOfferingRestore {
				isOfferingRestore = false
				restorePrompt = restorable
			}
		} catch {
			guard generation == loadGeneration else { return }
			isOfferingRestore = false
			if error as? BackupRestoreFailure == .signInRequired {
				signInWasRequired()
				return
			}
			errorMessage = "サーバーのバックアップがあるかを確かめられませんでした。時間をおいてもう一度お試しください"
		}
	}

	/// 401 で端末のトークンと状態が消えたとき。アカウントの欄に読み直してもらい、取り込みも聞かない。
	private func signInWasRequired() {
		onSignInRequired()
		status = backupRepository.status
		errorMessage = nil
		restorable = nil
		isOfferingRestore = false
	}

	private static func message(for failure: BackupFailure) -> String {
		switch failure {
		case .unreachable:
			"サーバーに届きませんでした。次にアプリを開いたときに、もう一度送ります"
		case .server:
			"サーバーで問題が起きました。次にアプリを開いたときに、もう一度送ります"
		case .signInRequired:
			"サインインし直してください"
		case .needsConfirmation:
			"ほかの端末から送ったバックアップと食い違っています"
		case .tooLarge:
			"記録が多すぎて送れませんでした"
		case .localReadFailed:
			"この iPhone の記録を読めませんでした。次にアプリを開いたときに、もう一度送ります"
		case .remoteDeletionFailed:
			"サーバーのバックアップを消せませんでした"
		}
	}

	private static func restoreMessage(for failure: BackupRestoreFailure) -> String {
		switch failure {
		case .unreachable:
			"サーバーに届きませんでした。時間をおいてもう一度お試しください"
		case .server:
			"サーバーで問題が起きました。時間をおいてもう一度お試しください"
		case .signInRequired:
			"サインインし直してください"
		case .notFound:
			"サーバーにバックアップがありませんでした"
		case .unsupportedVersion:
			"新しいバージョンのアプリで作ったバックアップです。アプリを更新してください"
		case .invalidContents:
			"バックアップの中身を読めなかったため、取り込みませんでした"
		case .localNotEmpty:
			"この iPhone にはもう記録があるため、取り込めません"
		case .localStoreFailed:
			"この iPhone に保存できませんでした。何も取り込んでいません"
		}
	}
}
#endif
