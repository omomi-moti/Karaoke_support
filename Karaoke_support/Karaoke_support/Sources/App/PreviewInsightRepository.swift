import Foundation

@MainActor
final class PreviewInsightRepository: InsightRepositoryProtocol {
	func fetchTimeMachineRanking() async throws -> [InsightTrackCountRanking] {
		let trackIdA = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
		let trackIdB = UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID()
		return [
			InsightTrackCountRanking(
				id: trackIdA,
				trackId: trackIdA,
				spotifyTrackId: nil,
				userEnteredName: "残酷な天使のテーゼ",
				countInPeriod: 5
			),
			InsightTrackCountRanking(
				id: trackIdB,
				trackId: trackIdB,
				spotifyTrackId: "spotify:track:preview",
				userEnteredName: nil,
				countInPeriod: 3
			),
		]
	}

	func fetchMyAnthemRankings(period: InsightPeriod) async throws -> [MyAnthemRanking] {
		let timeMachine = try await fetchTimeMachineRanking()
		let byCount = timeMachine
		let byScore: [InsightTrackScoreRanking] = timeMachine.map {
			InsightTrackScoreRanking(
				id: $0.trackId,
				trackId: $0.trackId,
				spotifyTrackId: $0.spotifyTrackId,
				userEnteredName: $0.userEnteredName,
				bestScore: $0.userEnteredName == nil ? 78 : 95
			)
		}

		return [
			MyAnthemRanking(intent: .shout, byCount: byCount, byScore: byScore),
			MyAnthemRanking(intent: .emo, byCount: byCount, byScore: byScore),
			MyAnthemRanking(intent: .practice, byCount: byCount, byScore: byScore),
		]
	}
}

