import Foundation

/// 曲詳細の統計。主役は「直近スコアと前回差」で、回数・平均・最高は補足として持つ。0 件では生成しない。
///
/// 回数は点数なしの記録も数える。点数の統計は点数ありの記録だけから求め、1 件も無ければ `nil`。
struct TrackScoreSummary: Equatable {
	let count: Int
	let averageScore: Double?
	let bestScore: Double?
	/// 点数ありの記録のうち最新のもの。
	let latestScore: Double?
	/// 点数ありの記録どうしで、直前との差。点数ありが 1 件以下なら nil。
	let deltaFromPrevious: Double?

	init?(points: [TrackScoreTrendPoint]) {
		guard !points.isEmpty else { return nil }
		let scores = points.compactMap(\.score)
		self.count = points.count
		self.averageScore = scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)
		self.bestScore = scores.max()
		self.latestScore = scores.last
		if scores.count >= 2 {
			self.deltaFromPrevious = scores[scores.count - 1] - scores[scores.count - 2]
		} else {
			self.deltaFromPrevious = nil
		}
	}
}
