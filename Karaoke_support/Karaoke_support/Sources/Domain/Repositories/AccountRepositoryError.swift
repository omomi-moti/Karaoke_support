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
	/// アカウントの削除で、もう一度サインインした Apple ID が今のアカウントのものと違った（403、ADR 0057）。
	case appleAccountMismatch
	/// アカウントの削除で、サーバーが Apple のトークンか認可コードを受け付けなかった（400、ADR 0057）。
	case appleCredentialRejected
}
#endif
