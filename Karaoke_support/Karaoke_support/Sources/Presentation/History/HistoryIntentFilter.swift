import Foundation

/// 履歴一覧の Intent フィルター（I-014）。
enum HistoryIntentFilter: Hashable, Sendable {
	case all
	case intent(Intent)
}
