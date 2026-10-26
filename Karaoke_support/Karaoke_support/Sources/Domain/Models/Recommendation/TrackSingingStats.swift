import Foundation

/// 曲ごとの歌唱の集計（値型）。次の曲の提案（``NextTrackRecommender``）に使う。
///
/// 「最新の記録」から求める値は、`performedAt` が一番新しい記録で決める。
struct TrackSingingStats: Equatable, Sendable {
	let trackId: UUID
	let spotifyTrackId: String?
	let userEnteredName: String?
	/// 最新の記録の気分。
	let latestIntent: Intent
	/// 最新の記録の歌唱日時。
	let lastPerformedAt: Date
	/// 点数ありの記録の最高点。点数ありの記録がなければ `nil`。
	let bestScore: Double?
	/// 記録の数。
	let sessionCount: Int
	/// 最新の記録にハート（また歌いたい）が付いているか。
	var latestWantAgain = false
}
