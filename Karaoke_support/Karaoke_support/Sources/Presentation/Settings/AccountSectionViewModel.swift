#if DEBUG || BETA
import AuthenticationServices
import Foundation
import Observation

/// 設定のアカウントの欄（#152）。Sign in with Apple でサーバーにサインインし、自分のアカウントを出す。
/// サインインは取り消さずに、後から終わっても結果を書く（途中で読み込みが走っても、サインインの結果を残すため）。
@MainActor
@Observable
final class AccountSectionViewModel {
	enum Status: Equatable {
		case loading
		case signedOut
		case signedIn(Account)
		case failed(message: String)
	}

	private let accountRepository: any AccountRepositoryProtocol

	/// Apple に渡した nonce。サーバーには元の値を送るので、サインインが終わるまで持つ。
	@ObservationIgnored private var pendingNonce: SignInNonce?

	private(set) var status: Status = .loading

	init(accountRepository: any AccountRepositoryProtocol) {
		self.accountRepository = accountRepository
	}

	func load() async {
		guard accountRepository.isSignedIn else {
			status = .signedOut
			return
		}
		status = .loading
		await fetchAccount()
	}

	/// 新しい nonce を作って持ち、Apple の要求に入れるハッシュを返す。
	func makeHashedNonce() -> String {
		let nonce = SignInNonce.generate()
		pendingNonce = nonce
		return nonce.hashed
	}

	/// Apple から受け取った identity token でサーバーにサインインし、自分のアカウントを読む。
	func signIn(identityToken: Data?) async {
		let nonce = pendingNonce
		pendingNonce = nil
		guard let nonce, let identityToken, let token = String(data: identityToken, encoding: .utf8) else {
			status = .failed(message: Self.signInFailedMessage)
			return
		}
		status = .loading
		do {
			try await accountRepository.signInWithApple(identityToken: token, rawNonce: nonce.raw)
		} catch AccountRepositoryError.unauthorized {
			status = .failed(message: Self.signInFailedMessage)
			return
		} catch {
			show(error)
			return
		}
		await fetchAccount()
	}

	/// Apple のサインインの画面が失敗で閉じたとき。利用者がキャンセルしたときは何も出さない。
	func signInFailed(_ error: Error) {
		pendingNonce = nil
		if let authorizationError = error as? ASAuthorizationError, authorizationError.code == .canceled {
			return
		}
		status = .failed(message: Self.signInFailedMessage)
	}

	/// ログアウトする。サーバーに届かなくても端末のトークンは消えるので、失敗を出すのは端末から消せなかったときだけ。
	func signOut() async {
		status = .loading
		do {
			try await accountRepository.signOut()
			status = .signedOut
		} catch {
			status = .failed(message: "この iPhone からサインインの情報を消せませんでした")
		}
	}

	private static let signInFailedMessage = "サインインできませんでした。もう一度お試しください"

	private func fetchAccount() async {
		do {
			let account = try await accountRepository.fetchMe()
			guard !Task.isCancelled else { return }
			status = .signedIn(account)
		} catch {
			show(error)
		}
	}

	/// 画面を離れて読み込みが取り消されたときは、届かなかったのではないので何も出さない。
	private func show(_ error: Error) {
		guard !Task.isCancelled else { return }
		switch error as? AccountRepositoryError {
		case .unauthorized:
			status = .signedOut
		case .unreachable:
			status = .failed(message: "サーバーに届きませんでした。通信できる場所でもう一度お試しください")
		case .tokenStorage:
			status = .failed(message: "サインインの情報をこの iPhone に保存できませんでした")
		case .appleAccountMismatch:
			status = .failed(message: "サインインしている Apple ID と違うものが選ばれました。同じ Apple ID でもう一度お試しください")
		case .appleCredentialRejected:
			status = .failed(message: "Apple での確認ができませんでした。もう一度お試しください")
		case .server, nil:
			status = .failed(message: "サーバーで問題が起きました。時間をおいてもう一度お試しください")
		}
	}
}
#endif
