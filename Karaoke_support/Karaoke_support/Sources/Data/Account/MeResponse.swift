#if DEBUG || BETA
import Foundation

/// `GET /v1/me` の返事。
struct MeResponse: Decodable {
	let id: String
	let createdAt: Date
}
#endif
