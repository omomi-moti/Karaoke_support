#if DEBUG || BETA
import Foundation

/// AccountRepository のエラー。利用者の側の失敗と、サーバーや通信の失敗を分ける（ADR 0054）。
enum AccountRepositoryError: Error, Equatable {
	/// サーバーがトークンを受け付けなかった（401）。サインインし直す必要がある。
	case unauthorized
	/// サーバーに届かなかった（オフライン・タイムアウト）。
	case unreachable
	/// サーバーの側で失敗した（5xx）か、返事を読めなかった。
	case server
	/// 端末にトークンを保存できなかった。
	case tokenStorage
}
#endif
