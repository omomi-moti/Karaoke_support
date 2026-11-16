#if DEBUG || BETA
import Foundation

/// 取り込みの失敗の理由（ADR 0061）。送るときの失敗（``BackupFailure``）と違い、端末には置かずにその場で出す。
enum BackupRestoreFailure: Error, Equatable, Sendable {
	/// サーバーに届かなかった（オフライン・タイムアウト）。
	case unreachable
	/// サーバーの側で失敗した（5xx）。
	case server
	/// サーバーがトークンを受け付けなかった（401）か、取り込む途中でサインアウトされた。端末のトークンとバックアップの状態は消す。
	case signInRequired
	/// サーバーに控えがなかった（ほかの端末でオフにした・アカウントを消した）。
	case notFound
	/// このアプリが知らない形の控え（`schemaVersion` が違う）。新しいアプリで作った控えのときに起きる。
	case unsupportedVersion
	/// 控えの中身がおかしい（読めない・値が範囲の外・id や曲名が重なる・記録の曲がない）。何も取り込まない。
	case invalidContents
	/// この端末にもう曲か記録がある。記録を消さないため、取り込まない（ADR 0049 の 5-A）。
	case localNotEmpty
	/// この端末の記録を読めなかった・保存できなかった。何も残さない。
	case localStoreFailed
}
#endif
