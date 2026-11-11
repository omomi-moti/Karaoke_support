#if DEBUG || BETA
import Foundation

@MainActor
final class PreviewAccountRepository: AccountRepositoryProtocol {
	private(set) var isSignedIn: Bool

	/// 環境キーの初期値として、メインアクターの外で作られることがあるため（ADR 0027）。
	nonisolated init(isSignedIn: Bool = false) {
		self.isSignedIn = isSignedIn
	}

	func signInWithApple(identityToken: String, rawNonce: String) async throws {
		isSignedIn = true
	}

	func fetchMe() async throws -> Account {
		guard isSignedIn else { throw AccountRepositoryError.unauthorized }
		return Account(id: "7d9f0c4e-1111-2222-3333-444455556666", createdAt: Date())
	}
}
#endif
