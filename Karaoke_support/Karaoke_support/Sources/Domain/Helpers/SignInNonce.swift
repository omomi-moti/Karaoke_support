#if DEBUG || BETA
import CryptoKit
import Foundation

/// Sign in with Apple の nonce。Apple には ``hashed`` を、サーバーには ``raw`` を渡す。
/// サーバーは ``raw`` を同じ形でハッシュにして、Apple のトークンの nonce と比べる（ADR 0054）。
struct SignInNonce: Equatable, Sendable {
	let raw: String

	/// ``raw`` の SHA-256 を、小文字の 16 進数にしたもの。
	var hashed: String {
		SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
	}

	/// 32 バイトの乱数から、新しい nonce を作る。
	static func generate() -> SignInNonce {
		var generator = SystemRandomNumberGenerator()
		let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
		return SignInNonce(raw: bytes.map { String(format: "%02x", $0) }.joined())
	}
}
#endif
