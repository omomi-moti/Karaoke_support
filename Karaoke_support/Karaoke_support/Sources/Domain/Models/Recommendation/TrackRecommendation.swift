import Foundation

/// 次の曲の提案 1 件。
struct TrackRecommendation: Equatable, Sendable {
	let stats: TrackSingingStats
	/// 並べ替えに使うスコア（``NextTrackRecommender/score(bestScore:daysSinceLastSung:)``）。
	let score: Double
	/// 最後に歌ってから何日たったか。1 日の区切りは ``NextTrackRecommender/dayBoundaryHour`` 時。
	let daysSinceLastSung: Int
}
