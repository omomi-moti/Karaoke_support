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
	/// 最新の記録で歌い切れたか。
	var latestIsCompleted = true
	/// 最新の記録のメモ。
	var latestMemo: String?

	/// 挑戦中か。最新の記録の気分が Practice、または最新の記録で歌い切れなかった曲。
	/// 挑戦中の曲は Practice のチップ（練習中の曲・歌い切れなかった曲）にだけ出し、ほかの候補には出さない。
	var isChallenging: Bool { latestIntent == .practice || !latestIsCompleted }
}
