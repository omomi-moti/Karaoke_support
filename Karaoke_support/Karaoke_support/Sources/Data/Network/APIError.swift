#if DEBUG || BETA
import Foundation

/// 自前のサーバーへの通信の失敗。
enum APIError: Error, Equatable {
	/// 401。トークンがない・偽物・期限切れ。
	case unauthorized
	/// サーバーに届かなかった（オフライン・タイムアウト）。
	case unreachable
	/// 401 以外の失敗のステータス。
	case status(Int)
	/// 返事を読めなかった。
	case invalidResponse
}
#endif
