import Foundation

@MainActor
final class PreviewTrackStatsRepository: TrackStatsRepositoryProtocol {
	/// 環境キーの初期値として、メインアクターの外で作られることがあるため（ADR 0027）。
	nonisolated init() {}

	func fetchTrackSingingStats() async throws -> [TrackSingingStats] {
		let now = Date()
		func daysAgo(_ days: Int) -> Date {
			Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
		}
		return [
			TrackSingingStats(
				trackId: UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(),
				spotifyTrackId: nil,
				userEnteredName: "涙そうそう",
				latestIntent: .emo,
				lastPerformedAt: daysAgo(60),
				bestScore: 92.5,
				sessionCount: 4
			),
			TrackSingingStats(
				trackId: UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID(),
				spotifyTrackId: nil,
				userEnteredName: "さよならララ",
				latestIntent: .emo,
				lastPerformedAt: daysAgo(21),
				bestScore: nil,
				sessionCount: 2
			),
			TrackSingingStats(
				trackId: UUID(uuidString: "55555555-5555-5555-5555-555555555555") ?? UUID(),
				spotifyTrackId: nil,
				userEnteredName: "紅",
				latestIntent: .shout,
				lastPerformedAt: daysAgo(10),
				bestScore: 88,
				sessionCount: 6
			),
		]
	}
}
