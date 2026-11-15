#if DEBUG || BETA
import Foundation
import Observation

/// 設定のバックアップの欄（#161、ADR 0058・0059）。オン・オフ、最後のバックアップ、最後の失敗、「今すぐバックアップ」、
/// ほかの端末の控えとの食い違いの確認、オフにしたときに消せなかった控えの消し直しを扱う。
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
	}

	private let backupRepository: any BackupRepositoryProtocol
	/// 401 で端末のトークンとバックアップの状態が消えたときに呼ぶ。アカウントの欄を読み直すため。
	@ObservationIgnored private let onSignInRequired: () -> Void
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

	init(backupRepository: any BackupRepositoryProtocol, onSignInRequired: @escaping () -> Void = {}) {
		self.backupRepository = backupRepository
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
		if let message = await refresh() {
			errorMessage = message
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
			errorMessage = await refresh()
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
		let refreshMessage = await refresh()
		if let thrown, thrown != .signInRequired, thrown != status.lastFailure {
			errorMessage = Self.message(for: thrown)
		} else {
			errorMessage = refreshMessage
		}
	}

	/// 端末の状態を写し、「確認が要る」なら件数を読む。読み終えたときに新しい読み込みが始まっていたら、件数は書かない。
	/// 件数を読めなかったときは、出す文を返す（出すかどうかは呼ぶ側が決める）。
	private func refresh() async -> String? {
		loadGeneration += 1
		let generation = loadGeneration
		status = backupRepository.status
		guard status.lastFailure == .needsConfirmation else {
			conflict = nil
			return nil
		}
		do {
			let conflict = try await backupRepository.fetchConflict()
			guard generation == loadGeneration else { return nil }
			self.conflict = conflict
			return nil
		} catch {
			guard generation == loadGeneration else { return nil }
			conflict = nil
			if error as? BackupFailure == .signInRequired {
				onSignInRequired()
				status = backupRepository.status
				return nil
			}
			return "サーバーのバックアップの件数を読めませんでした。時間をおいてもう一度お試しください"
		}
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
}
#endif
