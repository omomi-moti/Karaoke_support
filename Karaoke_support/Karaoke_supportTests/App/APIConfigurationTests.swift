#if DEBUG || BETA
import Foundation
import Testing

@testable import Karaoke_support

@Suite("APIConfiguration")
struct APIConfigurationTests {

	@Test("Info.plist の値を使う")
	func usesInfoValue() {
		let url = APIConfiguration.baseURL(infoValue: "https://api.example.com", environment: [:])
		#expect(url == URL(string: "https://api.example.com"))
	}

	@Test("スキームの環境変数があれば、そちらを使う")
	func environmentOverridesInfoValue() {
		let url = APIConfiguration.baseURL(
			infoValue: "https://api.example.com",
			environment: ["KARAOKE_API_BASE_URL": "http://localhost:8080"]
		)
		#expect(url == URL(string: "http://localhost:8080"))
	}

	@Test("空・URL でない・https でない値は使わない（http は localhost だけ）", arguments: ["", "not a url", "ftp://api.example.com", "http://api.example.com", "$(API_BASE_URL)"])
	func rejectsInvalidValues(value: String) {
		#expect(APIConfiguration.baseURL(infoValue: value, environment: [:]) == nil)
		#expect(APIConfiguration.baseURL(infoValue: nil, environment: ["KARAOKE_API_BASE_URL": value]) == nil)
	}

	@Test("どちらもなければ nil")
	func nilWhenMissing() {
		#expect(APIConfiguration.baseURL(infoValue: nil, environment: [:]) == nil)
	}
}
#endif
