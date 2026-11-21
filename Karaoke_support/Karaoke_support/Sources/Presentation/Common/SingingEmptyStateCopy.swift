import Foundation

/// 歌唱データ 0 件時の Empty State 文言（I-016）。``SingingEmptyStateView`` とテストで共有する。
enum SingingEmptyStateCopy {
	/// `docs/v1_issues.md` [I-016] 本文どおり。
	static let headline = "まず1曲歌ってみよう！"
	/// `docs/v1_issues.md` [I-016] 導線ラベルどおり。
	static let manualEntryButtonTitle = "手動で曲名を入力して歌う"
	/// 空の画面から、その場でバックアップを取り込むボタン（ADR 0071）。
	static let restoreButtonTitle = "前の iPhone の記録を取り込む"
}
