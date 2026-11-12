#if DEBUG || BETA
import Foundation

/// `DELETE /v1/me` の本文（ADR 0057）。サーバーは知らない項目があると断るので、ここに項目を足すときはサーバーと合わせる。
struct DeleteAccountRequest: Encodable {
	let identityToken: String
	let authorizationCode: String
	let nonce: String
}
#endif
