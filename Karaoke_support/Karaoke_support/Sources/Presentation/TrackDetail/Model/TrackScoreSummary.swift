import Foundation

/// 曲詳細の統計。主役は「直近スコアと前回差」で、回数・平均・最高は補足として持つ。0 件では生成しない。
struct TrackScoreSummary: Equatable {
	let count: Int
	let averageScore: Double
	let bestScore: Double
	let latestScore: Double
	/// 直前の記録との差。1 件目では nil。
	let deltaFromPrevious: Double?

	init?(points: [TrackScoreTrendPoint]) {
		guard let latest = points.last else { return nil }
		let scores = points.map(\.score)
		self.count = scores.count
		self.averageScore = scores.reduce(0, +) / Double(scores.count)
		self.bestScore = scores.max() ?? latest.score
		self.latestScore = latest.score
		if points.count >= 2 {
			self.deltaFromPrevious = latest.score - points[points.count - 2].score
		} else {
			self.deltaFromPrevious = nil
		}
	}
}
