#if DEBUG || BETA
import Foundation

/// 自前のサーバーと Keychain で、アカウントを扱う。
/// 端末のトークンを消すとき（サインアウト・アカウントの削除・401）は、バックアップの状態も一緒に消す（ADR 0058）。
@MainActor
final class RemoteAccountRepository: AccountRepositoryProtocol {
	private let client: APIClient
	private let tokenStore: any ServerTokenStoring
	private let backupState: any BackupStateStoring

	init(client: APIClient, tokenStore: any ServerTokenStoring, backupState: any BackupStateStoring) {
		self.client = client
		self.tokenStore = tokenStore
		self.backupState = backupState
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
		let response: MeResponse
		do {
			response = try await call {
				try await client.send("GET", "v1/me", bearer: token)
			}
		} catch AccountRepositoryError.unauthorized {
			try? tokenStore.delete()
			backupState.clear()
			throw AccountRepositoryError.unauthorized
		}
		return Account(id: response.id, createdAt: response.createdAt)
	}

	func signOut() async throws {
		if let token = try? tokenStore.read() {
			try? await client.sendExpectingNoContent("DELETE", "v1/auth/session", bearer: token)
		}
		backupState.clear()
		do {
			try tokenStore.delete()
		} catch {
			throw AccountRepositoryError.tokenStorage
		}
	}

	func deleteAccount(identityToken: String, authorizationCode: String, rawNonce: String) async throws {
		guard let token = try? tokenStore.read() else {
			throw AccountRepositoryError.unauthorized
		}
		let body = DeleteAccountRequest(identityToken: identityToken, authorizationCode: authorizationCode, nonce: rawNonce)
		do {
			try await call {
				do {
					try await client.sendExpectingNoContent("DELETE", "v1/me", body: body, bearer: token)
				} catch APIError.status(403) {
					throw AccountRepositoryError.appleAccountMismatch
				} catch APIError.status(400) {
					throw AccountRepositoryError.appleCredentialRejected
				}
			}
		} catch AccountRepositoryError.unauthorized {
			try? tokenStore.delete()
			backupState.clear()
			throw AccountRepositoryError.unauthorized
		}
		try? tokenStore.delete()
		backupState.clear()
	}

	private func call<Response>(_ body: () async throws -> Response) async throws -> Response {
		do {
			return try await body()
		} catch APIError.unauthorized {
			throw AccountRepositoryError.unauthorized
		} catch APIError.unreachable {
			throw AccountRepositoryError.unreachable
		} catch let error as AccountRepositoryError {
			throw error
		} catch {
			throw AccountRepositoryError.server
		}
	}
}
#endif
