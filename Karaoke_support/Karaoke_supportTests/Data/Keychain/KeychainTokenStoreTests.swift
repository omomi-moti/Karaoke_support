#if DEBUG || BETA
import Foundation
import Testing

@testable import Karaoke_support

@Suite("KeychainTokenStore")
struct KeychainTokenStoreTests {

	@Test("保存した値を読め、上書きでき、消すと読めなくなる")
	func roundTrip() throws {
		let store = KeychainTokenStore(service: "test.\(UUID().uuidString)")
		defer { try? store.delete() }

		#expect(try store.read() == nil)

		try store.save("klog_first")
		#expect(try store.read() == "klog_first")

		try store.save("klog_second")
		#expect(try store.read() == "klog_second")

		try store.delete()
		#expect(try store.read() == nil)
		try store.delete()
	}
}
#endif
