import Foundation

/// 履歴タブの `NavigationStack` が扱う遷移先。
/// 行タップ＝曲詳細。編集（リードスワイプ）は `RootView` の記録シートで開くので、ここには含めない。
enum HistoryRoute: Hashable {
	case trackDetail(trackId: UUID, title: String)
}
