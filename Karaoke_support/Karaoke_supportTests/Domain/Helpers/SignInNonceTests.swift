#if DEBUG || BETA
import Foundation
import Testing

@testable import Karaoke_support

@Suite("SignInNonce")
struct SignInNonceTests {

	@Test("Apple に渡す値は、元の値の SHA-256 を小文字の 16 進数にしたもの")
	func hashedIsSHA256Hex() {
		let nonce = SignInNonce(raw: "abc")
		#expect(nonce.hashed == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
	}

	@Test("作るたびに、32 バイトの違う値になる")
	func generateIsRandom() {
		let first = SignInNonce.generate()
		let second = SignInNonce.generate()
		#expect(first.raw.count == 64)
		#expect(first.raw.allSatisfy { "0123456789abcdef".contains($0) })
		#expect(first != second)
	}
}
#endif
