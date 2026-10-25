import Foundation

/// 入口（``RecordSource``）ごとの記録の数（値型）。選曲MVP の仮説を確かめるために設定画面に出す（#120）。
///
/// 入口を記録し始める前の記録（入口が空）は、どちらの数にも入れない。
struct RecordSourceCounts: Equatable, Sendable {
	/// 保存直後の提案から付けた記録の数。
	let suggestion: Int
	/// 入口を記録し始めてから付けた記録の数（提案から付けた記録を含む）。
	let recorded: Int
}
