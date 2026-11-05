import Foundation

/// 検索タブのカード 1 枚分の **表示専用** スナップショット（#142）。検索結果と「最近歌った曲」の両方に使う。
///
/// 履歴一覧（``HistorySessionRowDisplayItem``）と同じく、SwiftData の ``Track`` を行に直接渡さず、読んだ直後に値だけを写す。
struct SearchResultDisplayItem: Identifiable, Equatable {
	/// 曲の ID。
	let id: UUID
	let spotifyTrackId: String?
	let userEnteredName: String?
	let title: String
	/// 例:「4回歌った ・ 前回は5日前」。
	let history: String
	/// 最新の記録の気分。記録が 1 件もない曲は `nil`。
	let latestIntent: Intent?
	/// 最新の記録にハートが付いているか。
	let isWantAgain: Bool

	/// 記録が 1 件もない曲は、回数だけ（「0回歌った」）にする。
	init(track: Track, now: Date, calendar: Calendar) {
		let latest = track.sessions.max(by: { $0.performedAt < $1.performedAt })
		id = track.id
		spotifyTrackId = track.spotifyTrackId
		userEnteredName = track.userEnteredName
		title = TrackDisplayTitle.primary(for: track)
		history = Self.history(count: track.sessions.count, lastPerformedAt: latest?.performedAt, now: now, calendar: calendar)
		latestIntent = latest?.intent
		isWantAgain = latest?.wantAgain ?? false
	}

	init(stats: TrackSingingStats, now: Date, calendar: Calendar) {
		id = stats.trackId
		spotifyTrackId = stats.spotifyTrackId
		userEnteredName = stats.userEnteredName
		title = TrackDisplayTitle.primary(spotifyTrackId: stats.spotifyTrackId, userEnteredName: stats.userEnteredName)
		history = Self.history(count: stats.sessionCount, lastPerformedAt: stats.lastPerformedAt, now: now, calendar: calendar)
		latestIntent = stats.latestIntent
		isWantAgain = stats.latestWantAgain
	}

	/// 行の 2 行目。例:「4回歌った ・ 前回は5日前 ・ Shout」。記録のない曲は気分を付けない。
	var subtitle: String {
		guard let latestIntent else { return history }
		return "\(history) ・ \(IntentLabel.title(latestIntent))"
	}

	private static func history(count: Int, lastPerformedAt: Date?, now: Date, calendar: Calendar) -> String {
		guard let lastPerformedAt else { return "\(count)回歌った" }
		let days = max(NextTrackRecommender.daysBetween(lastPerformedAt, now, calendar: calendar), 0)
		return RecommendationReasonFormat.history(count: count, days: days)
	}
}
