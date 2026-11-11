#if DEBUG || BETA
import Foundation

/// 自前のサーバーのつなぎ先を決める（docs/backend_design.md の「環境」）。
enum APIConfiguration {
	/// スキームの環境変数 `KARAOKE_API_BASE_URL` があればそれを、なければ Info.plist の `APIBaseURL`（ビルド設定の `API_BASE_URL`）を使う。
	/// どちらも空なら nil を返し、アカウントの機能を出さない。
	static func baseURL(
		infoValue: Any? = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL"),
		environment: [String: String] = ProcessInfo.processInfo.environment
	) -> URL? {
		if let override = environment["KARAOKE_API_BASE_URL"], let url = serverURL(override) {
			return url
		}
		guard let value = infoValue as? String else { return nil }
		return serverURL(value)
	}

	/// トークンを平文で送らないように、`https` だけを受け付ける。`http` は手元のサーバー（localhost）だけ許す。
	private static func serverURL(_ string: String) -> URL? {
		guard let url = URL(string: string), let host = url.host() else { return nil }
		switch url.scheme {
		case "https":
			return url
		case "http":
			return ["localhost", "127.0.0.1", "::1"].contains(host) ? url : nil
		default:
			return nil
		}
	}
}
#endif
