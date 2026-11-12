#if DEBUG || BETA
import Foundation

/// 自前のサーバーと Keychain で、アカウントを扱う。
@MainActor
final class RemoteAccountRepository: AccountRepositoryProtocol {
	private let client: APIClient
	private let tokenStore: any ServerTokenStoring

	init(client: APIClient, tokenStore: any ServerTokenStoring) {
		self.client = client
		self.tokenStore = tokenStore
	}

	var isSignedIn: Bool {
		(try? tokenStore.read()) != nil
	}

	func signInWithApple(identityToken: String, rawNonce: String) async throws {
		let response: SignInWithAppleResponse = try await call {
			try await client.send("POST", "v1/auth/apple", body: SignInWithAppleRequest(identityToken: identityToken, nonce: rawNonce))
		}
		do {
			try tokenStore.save(response.token)
		} catch {
			throw AccountRepositoryError.tokenStorage
		}
	}

	func fetchMe() async throws -> Account {
		guard let token = try? tokenStore.read() else {
			throw AccountRepositoryError.unauthorized
		}
		let response: MeResponse = try await call {
			try await client.send("GET", "v1/me", bearer: token)
		}
		return Account(id: response.id, createdAt: response.createdAt)
	}

	private func call<Response>(_ body: () async throws -> Response) async throws -> Response {
		do {
			return try await body()
		} catch APIError.unauthorized {
			throw AccountRepositoryError.unauthorized
		} catch APIError.unreachable {
			throw AccountRepositoryError.unreachable
		} catch {
			throw AccountRepositoryError.server
		}
	}
}
#endif
