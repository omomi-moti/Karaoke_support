#if DEBUG || BETA
import Foundation

/// `POST /v1/auth/apple` の返事。`token` はこの 1 回だけ返るので、すぐに Keychain に置く。
struct SignInWithAppleResponse: Decodable {
	let token: String
	let expiresAt: Date
}
#endif
