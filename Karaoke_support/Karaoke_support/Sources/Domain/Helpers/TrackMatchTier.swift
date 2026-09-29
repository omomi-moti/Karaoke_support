import Foundation

/// 入力文字列が曲名のどこで一致したか。値が小さいほど上に並べる。
///
/// 入力途中の人は、打った文字で「始まる」ものを探していることが多い。
/// そのため曲名の先頭で始まる前方一致を最上位にし、途中の単語が打った文字で始まる単語の先頭一致を次に置く
/// （「live」と打った人には「Lemon (Live)」の方が、途中に live を含むだけの曲より意図に近い）。
/// 単語の頭ですらない部分一致は、打った文字列を含んでいるだけなので最下位にする。
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
