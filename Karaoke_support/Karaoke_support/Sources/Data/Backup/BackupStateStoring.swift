#if DEBUG || BETA
import Foundation

/// バックアップの状態を端末に置くもの（ADR 0058）。置くのはこの 5 つだけ。テストでは偽物に差し替える。
@MainActor
protocol BackupStateStoring: AnyObject, Sendable {
	var isEnabled: Bool { get set }
	/// 同意した画面の版。
	var consentVersion: Int? { get set }
	/// 最後に送れたときにサーバーが返した版。次に送るときの `If-Match` に使う。
	var lastRevision: Int? { get set }
	var lastSucceededAt: Date? { get set }
	var lastFailure: BackupFailure? { get set }
	/// `clear()` を呼んだ回数。メモリにだけ持つ。送っている途中に状態が消されたかを見分けるため。
	/// 見分けられるように、アカウントとバックアップの Repository には同じものを渡す。
	var clearCount: Int { get }

	/// 5 つとも消す。サインアウト・アカウントの削除・オフにして控えを消せたときに呼ぶ。
	func clear()
}
#endif
