#if DEBUG || BETA
import Foundation
import Testing

@testable import Karaoke_support

/// テストごとに別のホスト名を割り当て、そのホストへの通信だけを差し替える。テストを並べて流しても混ざらない。
private final class StubURLProtocol: URLProtocol {
	typealias Handler = @Sendable (URLRequest, Data?) throws -> (Int, Data)

	private static let lock = NSLock()
	nonisolated(unsafe) private static var handlers: [String: Handler] = [:]

	static func register(_ handler: @escaping Handler) -> URL {
		let host = "\(UUID().uuidString.lowercased()).test"
		lock.withLock { handlers[host] = handler }
		return URL(string: "https://\(host)")!
	}

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		let handler = Self.lock.withLock { request.url?.host.flatMap { Self.handlers[$0] } }
		guard let handler, let url = request.url else {
			client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
			return
		}
		do {
			let (status, data) = try handler(request, Self.readBody(request))
			let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
			client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
			client?.urlProtocol(self, didLoad: data)
			client?.urlProtocolDidFinishLoading(self)
		} catch {
			client?.urlProtocol(self, didFailWithError: error)
		}
	}

	override func stopLoading() {}

	/// URLSession は本文を stream にして渡すので、読み直す。
	private static func readBody(_ request: URLRequest) -> Data? {
		if let body = request.httpBody { return body }
		guard let stream = request.httpBodyStream else { return nil }
		stream.open()
		defer { stream.close() }
		var data = Data()
		var buffer = [UInt8](repeating: 0, count: 1024)
		while stream.hasBytesAvailable {
			let count = stream.read(&buffer, maxLength: buffer.count)
			guard count > 0 else { break }
			data.append(buffer, count: count)
		}
		return data
	}
}

/// 通信を受けた回数と、最後のリクエストを覚える。
private final class RequestLog: @unchecked Sendable {
	private let lock = NSLock()
	private var _requests: [(URLRequest, Data?)] = []

	func append(_ request: URLRequest, _ body: Data?) {
		lock.withLock { _requests.append((request, body)) }
	}

	var count: Int { lock.withLock { _requests.count } }
	var last: (URLRequest, Data?)? { lock.withLock { _requests.last } }
}

private final class InMemoryTokenStore: ServerTokenStoring, @unchecked Sendable {
	private let lock = NSLock()
	private var token: String?
	private let isFailingToSave: Bool
	private let isFailingToDelete: Bool

	init(token: String? = nil, isFailingToSave: Bool = false, isFailingToDelete: Bool = false) {
		self.token = token
		self.isFailingToSave = isFailingToSave
		self.isFailingToDelete = isFailingToDelete
	}

	func read() throws -> String? { lock.withLock { token } }

	func save(_ token: String) throws {
		if isFailingToSave { throw KeychainError(status: errSecInteractionNotAllowed) }
		lock.withLock { self.token = token }
	}

	func delete() throws {
		if isFailingToDelete { throw KeychainError(status: errSecInteractionNotAllowed) }
		lock.withLock { token = nil }
	}
}

@Suite("RemoteAccountRepository")
@MainActor
struct RemoteAccountRepositoryTests {

	private func makeRepository(
		tokenStore: InMemoryTokenStore = InMemoryTokenStore(),
		log: RequestLog = RequestLog(),
		respond: @escaping @Sendable (URLRequest) throws -> (Int, String)
	) -> RemoteAccountRepository {
		let baseURL = StubURLProtocol.register { request, body in
			log.append(request, body)
			let (status, text) = try respond(request)
			return (status, Data(text.utf8))
		}
		let session = APIClient.makeSession(protocolClasses: [StubURLProtocol.self])
		return RemoteAccountRepository(client: APIClient(baseURL: baseURL, session: session), tokenStore: tokenStore)
	}

	@Test("サインインすると、Apple のトークンと nonce の元の値を送り、返ったトークンを保存する")
	func signInSavesToken() async throws {
		let tokenStore = InMemoryTokenStore()
		let log = RequestLog()
		let repository = makeRepository(tokenStore: tokenStore, log: log) { _ in
			(200, #"{"token":"klog_issued","expiresAt":"2027-02-08T11:18:18.123456789Z"}"#)
		}

		#expect(!repository.isSignedIn)
		try await repository.signInWithApple(identityToken: "apple-id-token", rawNonce: "raw-nonce")

		#expect(try tokenStore.read() == "klog_issued")
		#expect(repository.isSignedIn)

		let (request, body) = try #require(log.last)
		#expect(request.httpMethod == "POST")
		#expect(request.url?.path == "/v1/auth/apple")
		#expect(request.value(forHTTPHeaderField: "Authorization") == nil)
		let sent = try JSONSerialization.jsonObject(with: try #require(body)) as? [String: String]
		#expect(sent == ["identityToken": "apple-id-token", "nonce": "raw-nonce"])
	}

	@Test("サインインに失敗したら、種類ごとのエラーになり、トークンを保存しない", arguments: [
		(401, AccountRepositoryError.unauthorized),
		(500, AccountRepositoryError.server),
		(200, AccountRepositoryError.server),
	])
	func signInFailures(status: Int, expected: AccountRepositoryError) async throws {
		let tokenStore = InMemoryTokenStore()
		let repository = makeRepository(tokenStore: tokenStore) { _ in
			(status, status == 200 ? "not json" : #"{"error":"x"}"#)
		}

		await #expect(throws: expected) {
			try await repository.signInWithApple(identityToken: "apple-id-token", rawNonce: "raw-nonce")
		}
		#expect(try tokenStore.read() == nil)
	}

	@Test("サーバーに届かなければ unreachable")
	func signInUnreachable() async throws {
		let repository = makeRepository { _ in throw URLError(.notConnectedToInternet) }

		await #expect(throws: AccountRepositoryError.unreachable) {
			try await repository.signInWithApple(identityToken: "apple-id-token", rawNonce: "raw-nonce")
		}
	}

	@Test("トークンを保存できなければ tokenStorage")
	func signInTokenStorageFailure() async throws {
		let repository = makeRepository(tokenStore: InMemoryTokenStore(isFailingToSave: true)) { _ in
			(200, #"{"token":"klog_issued","expiresAt":"2027-02-08T11:18:18Z"}"#)
		}

		await #expect(throws: AccountRepositoryError.tokenStorage) {
			try await repository.signInWithApple(identityToken: "apple-id-token", rawNonce: "raw-nonce")
		}
	}

	@Test("自分の情報は、保存したトークンを Bearer で送って読む")
	func fetchMeSendsBearer() async throws {
		let log = RequestLog()
		let repository = makeRepository(tokenStore: InMemoryTokenStore(token: "klog_saved"), log: log) { _ in
			(200, #"{"id":"7d9f0c4e-1111-2222-3333-444455556666","createdAt":"2026-11-10T11:18:18.123456Z"}"#)
		}

		let account = try await repository.fetchMe()

		#expect(account.id == "7d9f0c4e-1111-2222-3333-444455556666")
		#expect(account.createdAt == Date(timeIntervalSince1970: 1_794_309_498.123456))
		let (request, _) = try #require(log.last)
		#expect(request.httpMethod == "GET")
		#expect(request.url?.path == "/v1/me")
		#expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer klog_saved")
	}

	@Test("トークンがなければ、通信せずに unauthorized")
	func fetchMeWithoutToken() async throws {
		let log = RequestLog()
		let repository = makeRepository(log: log) { _ in (200, "{}") }

		await #expect(throws: AccountRepositoryError.unauthorized) {
			_ = try await repository.fetchMe()
		}
		#expect(log.count == 0)
	}

	@Test("自分の情報で 401 なら、端末のトークンを消して unauthorized")
	func fetchMeUnauthorized() async throws {
		let tokenStore = InMemoryTokenStore(token: "klog_expired")
		let repository = makeRepository(tokenStore: tokenStore) { _ in
			(401, #"{"error":"unauthorized"}"#)
		}

		await #expect(throws: AccountRepositoryError.unauthorized) {
			_ = try await repository.fetchMe()
		}
		#expect(try tokenStore.read() == nil)
		#expect(!repository.isSignedIn)
	}

	@Test("自分の情報が 401 以外で失敗したら、端末のトークンを残す", arguments: [500, 0])
	func fetchMeFailureKeepsToken(status: Int) async throws {
		let tokenStore = InMemoryTokenStore(token: "klog_saved")
		let repository = makeRepository(tokenStore: tokenStore) { _ in
			if status == 0 { throw URLError(.notConnectedToInternet) }
			return (status, #"{"error":"x"}"#)
		}

		await #expect(throws: (any Error).self) {
			_ = try await repository.fetchMe()
		}
		#expect(try tokenStore.read() == "klog_saved")
	}

	@Test("ログアウトすると、トークンを Bearer で送って消してもらい、端末のトークンも消す")
	func signOutSendsDeleteAndClearsToken() async throws {
		let tokenStore = InMemoryTokenStore(token: "klog_saved")
		let log = RequestLog()
		let repository = makeRepository(tokenStore: tokenStore, log: log) { _ in (204, "") }

		try await repository.signOut()

		#expect(try tokenStore.read() == nil)
		#expect(!repository.isSignedIn)
		let (request, _) = try #require(log.last)
		#expect(request.httpMethod == "DELETE")
		#expect(request.url?.path == "/v1/auth/session")
		#expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer klog_saved")
	}

	@Test("サーバーが失敗しても届かなくても、端末のトークンは消してエラーにしない", arguments: [401, 500, 0])
	func signOutClearsTokenEvenWhenServerFails(status: Int) async throws {
		let tokenStore = InMemoryTokenStore(token: "klog_saved")
		let repository = makeRepository(tokenStore: tokenStore) { _ in
			if status == 0 { throw URLError(.notConnectedToInternet) }
			return (status, #"{"error":"x"}"#)
		}

		try await repository.signOut()

		#expect(try tokenStore.read() == nil)
	}

	@Test("トークンがなければ、通信せずに終わる")
	func signOutWithoutToken() async throws {
		let log = RequestLog()
		let repository = makeRepository(log: log) { _ in (204, "") }

		try await repository.signOut()

		#expect(log.count == 0)
	}

	@Test("アカウントを消すと、Bearer と Apple の 3 つの値を DELETE /v1/me に送り、端末のトークンも消す")
	func deleteAccountSendsBodyAndClearsToken() async throws {
		let tokenStore = InMemoryTokenStore(token: "klog_saved")
		let log = RequestLog()
		let repository = makeRepository(tokenStore: tokenStore, log: log) { _ in (204, "") }

		try await repository.deleteAccount(identityToken: "apple-id-token", authorizationCode: "apple-code", rawNonce: "raw-nonce")

		#expect(try tokenStore.read() == nil)
		let (request, body) = try #require(log.last)
		#expect(request.httpMethod == "DELETE")
		#expect(request.url?.path == "/v1/me")
		#expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer klog_saved")
		let sent = try JSONSerialization.jsonObject(with: try #require(body)) as? [String: String]
		#expect(sent == ["identityToken": "apple-id-token", "authorizationCode": "apple-code", "nonce": "raw-nonce"])
	}

	@Test("アカウントを消せなければ種類ごとのエラーになり、401 のときだけ端末のトークンを消す", arguments: [
		(401, AccountRepositoryError.unauthorized, true),
		(403, AccountRepositoryError.appleAccountMismatch, false),
		(400, AccountRepositoryError.appleCredentialRejected, false),
		(500, AccountRepositoryError.server, false),
		(0, AccountRepositoryError.unreachable, false),
	])
	func deleteAccountFailures(status: Int, expected: AccountRepositoryError, clearsToken: Bool) async throws {
		let tokenStore = InMemoryTokenStore(token: "klog_saved")
		let repository = makeRepository(tokenStore: tokenStore) { _ in
			if status == 0 { throw URLError(.notConnectedToInternet) }
			return (status, #"{"error":"x"}"#)
		}

		await #expect(throws: expected) {
			try await repository.deleteAccount(identityToken: "apple-id-token", authorizationCode: "apple-code", rawNonce: "raw-nonce")
		}
		#expect((try tokenStore.read() == nil) == clearsToken)
	}

	@Test("アカウントの削除で、トークンがなければ通信せずに unauthorized")
	func deleteAccountWithoutToken() async throws {
		let log = RequestLog()
		let repository = makeRepository(log: log) { _ in (204, "") }

		await #expect(throws: AccountRepositoryError.unauthorized) {
			try await repository.deleteAccount(identityToken: "apple-id-token", authorizationCode: "apple-code", rawNonce: "raw-nonce")
		}
		#expect(log.count == 0)
	}

	@Test("サインインの 400 は、Apple の確認の失敗ではなくサーバーの失敗のまま")
	func signInBadRequestStaysServer() async throws {
		let repository = makeRepository { _ in (400, #"{"error":"invalid_request"}"#) }

		await #expect(throws: AccountRepositoryError.server) {
			try await repository.signInWithApple(identityToken: "apple-id-token", rawNonce: "raw-nonce")
		}
	}

	@Test("端末のトークンを消せなければ tokenStorage")
	func signOutTokenStorageFailure() async throws {
		let repository = makeRepository(tokenStore: InMemoryTokenStore(token: "klog_saved", isFailingToDelete: true)) { _ in (204, "") }

		await #expect(throws: AccountRepositoryError.tokenStorage) {
			try await repository.signOut()
		}
	}
}
#endif
