#if DEBUG || BETA
import Foundation

/// 空の端末に取り込めるサーバーの控えの、件数と日時（FR-5、ADR 0061）。取り込むかを聞くときに見せる。
struct BackupRestorableSummary: Equatable, Sendable {
	let sessionCount: Int
	/// サーバーの控えを最後に置き換えた日時。
	let updatedAt: Date
}
#endif
