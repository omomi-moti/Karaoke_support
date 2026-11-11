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

	init(token: String? = nil, isFailingToSave: Bool = false) {
		self.token = token
		self.isFailingToSave = isFailingToSave
	}

	func read() throws -> String? { lock.withLock { token } }

	func save(_ token: String) throws {
		if isFailingToSave { throw KeychainError(status: errSecInteractionNotAllowed) }
		lock.withLock { self.token = token }
	}

	func delete() throws { lock.withLock { token = nil } }
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

	@Test("自分の情報で 401 なら unauthorized")
	func fetchMeUnauthorized() async throws {
		let repository = makeRepository(tokenStore: InMemoryTokenStore(token: "klog_expired")) { _ in
			(401, #"{"error":"unauthorized"}"#)
		}

		await #expect(throws: AccountRepositoryError.unauthorized) {
			_ = try await repository.fetchMe()
		}
	}
}
#endif
