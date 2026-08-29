import Foundation

/// 履歴タブの `NavigationStack` が扱う遷移先。
/// 行タップ＝曲詳細、リードスワイプ＝編集。どちらも UUID を運ぶため型で区別する。
enum HistoryRoute: Hashable {
	case trackDetail(trackId: UUID, title: String)
	case editSession(sessionId: UUID)
}
