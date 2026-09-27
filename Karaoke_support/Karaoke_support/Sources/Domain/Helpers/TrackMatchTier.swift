import Foundation

/// 入力文字列が曲名のどこで一致したか。値が小さいほど上に並べる。
enum TrackMatchTier: Int, Comparable, Sendable {
	/// 先頭から一致（「le」→「lemon」）
	case prefix = 0
	/// 途中の単語の先頭で一致（「live」→「Lemon (Live)」）
	case wordPrefix = 1
	/// それ以外の位置で一致（「mon」→「lemon」）
	case contains = 2

	static func < (lhs: Self, rhs: Self) -> Bool {
		lhs.rawValue < rhs.rawValue
	}
}
