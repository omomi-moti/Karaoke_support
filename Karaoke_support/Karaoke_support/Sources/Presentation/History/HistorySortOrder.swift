import Foundation

/// 履歴一覧の並び順（I-014-B）。
///
/// **適用順は `Intent` フィルター → 並び替え**（`filter → sort`）。Repository の `fetchAll` は日時降順の直近ウィンドウを返すが、
/// 表示前に本列挙に従って再整列する。
enum HistorySortOrder: String, CaseIterable, Hashable, Sendable {
	/// 歌唱日時の新しい順（既定）。`performedAt` 降順。
	case performedAtDescending
	/// 歌唱日時の古い順。`performedAt` 昇順。
	case performedAtAscending
	/// 点数の高い順。
	case scoreDescending
	/// 点数の低い順。
	case scoreAscending

	/// メニュー／Picker 用の短いラベル。
	var pickerLabel: String {
		switch self {
		case .performedAtDescending: return "日付・新しい順"
		case .performedAtAscending: return "日付・古い順"
		case .scoreDescending: return "点数・高い順"
		case .scoreAscending: return "点数・低い順"
		}
	}

	/// アクセシビリティ用。
	var accessibilityDescription: String {
		switch self {
		case .performedAtDescending: return "歌唱日時が新しい順"
		case .performedAtAscending: return "歌唱日時が古い順"
		case .scoreDescending: return "点数が高い順"
		case .scoreAscending: return "点数が低い順"
		}
	}

	/// `HistorySessionRowDisplayItem` の配列を本順序で整列する（同一キー時は `performedAt` 降順 → `id` で安定化）。
	func sorted(_ items: [HistorySessionRowDisplayItem]) -> [HistorySessionRowDisplayItem] {
		items.sorted { lhs, rhs in
			switch self {
			case .performedAtDescending:
				if lhs.performedAt != rhs.performedAt { return lhs.performedAt > rhs.performedAt }
				return lhs.id.uuidString < rhs.id.uuidString
			case .performedAtAscending:
				if lhs.performedAt != rhs.performedAt { return lhs.performedAt < rhs.performedAt }
				return lhs.id.uuidString < rhs.id.uuidString
			case .scoreDescending:
				if lhs.score != rhs.score { return lhs.score > rhs.score }
				if lhs.performedAt != rhs.performedAt { return lhs.performedAt > rhs.performedAt }
				return lhs.id.uuidString < rhs.id.uuidString
			case .scoreAscending:
				if lhs.score != rhs.score { return lhs.score < rhs.score }
				if lhs.performedAt != rhs.performedAt { return lhs.performedAt > rhs.performedAt }
				return lhs.id.uuidString < rhs.id.uuidString
			}
		}
	}
}
