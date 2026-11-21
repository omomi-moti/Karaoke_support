#if DEBUG || BETA
import AuthenticationServices
import Foundation
import Observation

/// 履歴と選曲の空の画面から、その場でサインインして前の iPhone の記録を取り込む（#195、ADR 0071）。
/// サインインしていなければ Apple のサインインから始め、控えの件数と日時を見せて取り込むかを聞く。
/// 動いている間は次の操作を受け付けない。最初の読み込みと、押したあとの操作が重ならないようにするため。
@MainActor
@Observable
final class RestoreFromEmptyStateViewModel {
	enum Activity: Equatable {
		case signingIn
		case checking
		case restoring
	}

	private let accountRepository: any AccountRepositoryProtocol
	private let backupRepository: any BackupRepositoryProtocol

	/// Apple に渡した nonce。サーバーには元の値を送るので、サインインが終わるまで持つ。
	@ObservationIgnored private var pendingNonce: SignInNonce?

	private(set) var activity: Activity?
	/// ボタンを出すか。サインイン中で、サーバーに取り込める控えがないと分かったときだけ `false`（ADR 0071）。
	private(set) var isAvailable = true
	/// 取り込むかを聞く控え。聞いている間だけ入る。
	private(set) var restorePrompt: BackupRestorableSummary?
	/// 控えがなかった・失敗したときの文。次の操作を始めたら消す。
	private(set) var errorMessage: String?
	/// 取り込めた記録の件数。入ったら、画面に記録を読み直してもらう。
	private(set) var restoredSessionCount: Int?
	/// 取り込めたときにバックアップがオフなら `true` にし、オンにするかを聞く（#197、ADR 0072）。
	/// 聞いている間は記録を読み直さない。読み直すと空の画面が消え、聞いている alert も消えるため。
	private(set) var isOfferingEnable = false

	init(accountRepository: any AccountRepositoryProtocol, backupRepository: any BackupRepositoryProtocol) {
		self.accountRepository = accountRepository
		self.backupRepository = backupRepository
	}

	var isWorking: Bool {
		activity != nil
	}

	/// 押したときに、先に Apple のサインインが要るか。
	var needsSignIn: Bool {
		!accountRepository.isSignedIn
	}

	/// サインイン中なら、取り込める控えがあるかを読み、なければボタンを隠す。読めなかったときは、押せば読み直せるように出したままにする。
	/// サインインしていなければボタンを出す。前に隠したあと、ログアウトなどでサインインが切れたときに戻すため。
	func load() async {
		guard !isWorking else { return }
		guard accountRepository.isSignedIn else {
			isAvailable = true
			return
		}
		activity = .checking
		defer { activity = nil }
		do {
			isAvailable = try await backupRepository.fetchRestorableBackup() != nil
		} catch {
			isAvailable = true
		}
	}

	/// Apple のサインインを始める。新しい nonce を作って持ち、Apple の要求に入れるハッシュを返す。
	func beginSignIn() -> String {
		errorMessage = nil
		activity = .signingIn
		let nonce = SignInNonce.generate()
		pendingNonce = nonce
		return nonce.hashed
	}

	/// Apple から受け取った identity token でサーバーにサインインし、続けて取り込める控えを読んで聞く。
	func signIn(identityToken: Data?) async {
		let nonce = pendingNonce
		pendingNonce = nil
		guard let nonce, let identityToken, let token = String(data: identityToken, encoding: .utf8) else {
			activity = nil
			errorMessage = Self.signInFailedMessage
			return
		}
		do {
			try await accountRepository.signInWithApple(identityToken: token, rawNonce: nonce.raw)
		} catch {
			activity = nil
			errorMessage = Self.signInMessage(for: error)
			return
		}
		activity = nil
		await checkRestorable()
	}

	/// Apple のサインインの画面が失敗で閉じたとき。利用者がキャンセルしたときは何も出さない。
	func signInFailed(_ error: Error) {
		pendingNonce = nil
		activity = nil
		if let authorizationError = error as? ASAuthorizationError, authorizationError.code == .canceled {
			return
		}
		errorMessage = Self.signInFailedMessage
	}

	/// サインイン中に押したとき。取り込める控えを読み、あれば ``restorePrompt`` に入れて聞く。
	func checkRestorable() async {
		guard !isWorking else { return }
		activity = .checking
		errorMessage = nil
		defer { activity = nil }
		do {
			if let restorable = try await backupRepository.fetchRestorableBackup() {
				isAvailable = true
				restorePrompt = restorable
			} else {
				isAvailable = false
				errorMessage = Self.restoreMessage(for: .notFound)
			}
		} catch {
			show(error as? BackupRestoreFailure ?? .server)
		}
	}

	func cancelRestorePrompt() {
		restorePrompt = nil
	}

	/// オンにするかを聞き終えたとき。どちらを選んでも、もう聞かない。
	func endEnableOffer() {
		isOfferingEnable = false
	}

	/// サーバーの控えを、空の端末に取り込む。取り込めたら件数を ``restoredSessionCount`` に入れる。
	func restore() async {
		restorePrompt = nil
		guard !isWorking else { return }
		activity = .restoring
		errorMessage = nil
		defer { activity = nil }
		do {
			let restoredCount = try await backupRepository.restoreAll()
			isOfferingEnable = !backupRepository.status.isActive
			restoredSessionCount = restoredCount
		} catch {
			show(error as? BackupRestoreFailure ?? .server)
		}
	}

	/// 失敗の文を出す。控えがなかったときと、端末にもう記録があるときは、押しても取り込めないのでボタンを隠す。
	private func show(_ failure: BackupRestoreFailure) {
		if failure == .notFound || failure == .localNotEmpty {
			isAvailable = false
		}
		errorMessage = Self.restoreMessage(for: failure)
	}

	private static let signInFailedMessage = "サインインできませんでした。もう一度お試しください"

	private static func signInMessage(for error: Error) -> String {
		switch error as? AccountRepositoryError {
		case .unreachable:
			"サーバーに届きませんでした。通信できる場所でもう一度お試しください"
		case .tokenStorage:
			"サインインの情報をこの iPhone に保存できませんでした"
		case .server:
			"サーバーで問題が起きました。時間をおいてもう一度お試しください"
		case .unauthorized, .appleAccountMismatch, .appleCredentialRejected, nil:
			signInFailedMessage
		}
	}

	private static func restoreMessage(for failure: BackupRestoreFailure) -> String {
		switch failure {
		case .unreachable:
			"サーバーに届きませんでした。時間をおいてもう一度お試しください"
		case .server:
			"サーバーで問題が起きました。時間をおいてもう一度お試しください"
		case .signInRequired:
			"サインインが切れました。もう一度押すと、サインインし直せます"
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
