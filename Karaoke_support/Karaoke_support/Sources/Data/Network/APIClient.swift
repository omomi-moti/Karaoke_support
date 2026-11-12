#if DEBUG || BETA
import Foundation

/// 自前のサーバーに JSON で問い合わせる。通信は 15 秒で諦め、キャッシュしない。
struct APIClient: Sendable {
	static let timeout: TimeInterval = 15

	let baseURL: URL
	private let session: URLSession

	init(baseURL: URL, session: URLSession = APIClient.makeSession()) {
		self.baseURL = baseURL
		self.session = session
	}

	/// トークンや記録を端末に残さないように、ディスクを使わない設定で作る。
	static func makeSession(protocolClasses: [AnyClass]? = nil) -> URLSession {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.timeoutIntervalForRequest = timeout
		configuration.timeoutIntervalForResource = timeout
		configuration.urlCache = nil
		configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
		if let protocolClasses {
			configuration.protocolClasses = protocolClasses
		}
		return URLSession(configuration: configuration)
	}

	/// `path` に本文なしで送り、返事を `Response` として読む。
	func send<Response: Decodable>(_ method: String, _ path: String, bearer: String? = nil) async throws -> Response {
		try await send(makeRequest(method, path, bearer: bearer))
	}

	/// `path` に `body` を JSON にして送り、返事を `Response` として読む。
	func send<Response: Decodable>(_ method: String, _ path: String, body: some Encodable, bearer: String? = nil) async throws -> Response {
		var request = makeRequest(method, path, bearer: bearer)
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(body)
		return try await send(request)
	}

	/// `path` に本文なしで送り、成功のステータスかだけを確かめる。返事の本文は読まない（204 など）。
	func sendExpectingNoContent(_ method: String, _ path: String, bearer: String? = nil) async throws {
		_ = try await data(for: makeRequest(method, path, bearer: bearer))
	}

	private func makeRequest(_ method: String, _ path: String, bearer: String?) -> URLRequest {
		var request = URLRequest(url: baseURL.appending(path: path))
		request.httpMethod = method
		request.setValue("application/json", forHTTPHeaderField: "Accept")
		if let bearer {
			request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
		}
		return request
	}

	private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
		let data = try await data(for: request)
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		do {
			return try decoder.decode(Response.self, from: data)
		} catch {
			throw APIError.invalidResponse
		}
	}

	private func data(for request: URLRequest) async throws -> Data {
		let data: Data
		let response: URLResponse
		do {
			(data, response) = try await session.data(for: request)
		} catch is URLError {
			throw APIError.unreachable
		}
		guard let http = response as? HTTPURLResponse else {
			throw APIError.invalidResponse
		}
		switch http.statusCode {
		case 200..<300:
			break
		case 401:
			throw APIError.unauthorized
		default:
			throw APIError.status(http.statusCode)
		}
		return data
	}
}
#endif
