#if DEBUG || BETA
import Foundation

/// サーバーのトークンを端末に置くもの。テストでは偽物に差し替える。
protocol ServerTokenStoring: Sendable {
	func read() throws -> String?
	func save(_ token: String) throws
	func delete() throws
}
#endif
