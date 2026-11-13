#if DEBUG || BETA
import Foundation

/// バックアップの失敗の理由。最後の失敗として端末に置き、設定に出す（ADR 0058）。
/// 置くときは RawValue の文字列にする。
enum BackupFailure: String, Error, Equatable, Sendable {
	/// サーバーに届かなかった（オフライン・タイムアウト）。
	case unreachable
	/// サーバーの側で失敗した（5xx）か、返事を読めなかった。
	case server
	/// サーバーがトークンを受け付けなかった（401）。端末のトークンとバックアップの状態は消すので、置かずに投げるだけ。
	case signInRequired
	/// サーバーの控えが、この端末が最後に送った版でない（412）。本人が確かめるまで自動では送らない。
	case needsConfirmation
	/// 大きすぎて受け付けられなかった（413）。
	case tooLarge
	/// この端末の記録を読めなかった。
	case localReadFailed
	/// オフにしたときに、サーバーのバックアップを消せなかった。
	case remoteDeletionFailed

	/// 前に戻ったときに、もう一度自動で送ってよい失敗か。確認が要るとき・オフにしたときは送らない。
	var isRetriedAutomatically: Bool {
		switch self {
		case .unreachable, .server, .localReadFailed:
			true
		case .signInRequired, .needsConfirmation, .tooLarge, .remoteDeletionFailed:
			false
		}
	}
}
#endif
