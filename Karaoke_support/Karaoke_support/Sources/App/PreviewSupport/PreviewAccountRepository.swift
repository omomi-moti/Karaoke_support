#if DEBUG || BETA
import Foundation

@MainActor
final class PreviewAccountRepository: AccountRepositoryProtocol {
	private(set) var isSignedIn: Bool

	/// ほかのプレビュー用の Repository とそろえる（ADR 0027）。環境の初期値は nil なので、これは使わない（ADR 0055）。
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
