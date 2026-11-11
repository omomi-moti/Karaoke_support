#if DEBUG || BETA
import Foundation

/// `POST /v1/auth/apple` の本文。サーバーは知らない項目があると断るので、ここに項目を足すときはサーバーと合わせる。
struct SignInWithAppleRequest: Encodable {
	let identityToken: String
	let nonce: String
}
#endif
