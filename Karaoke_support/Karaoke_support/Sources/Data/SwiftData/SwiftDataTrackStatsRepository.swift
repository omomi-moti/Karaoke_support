import Foundation
import SwiftData

@MainActor
final class SwiftDataTrackStatsRepository: TrackStatsRepositoryProtocol {
	private let modelContext: ModelContext

	init(modelContext: ModelContext) {
		self.modelContext = modelContext
	}

	func fetchTrackSingingStats() async throws -> [TrackSingingStats] {
		// 提案は全期間の記録から選ぶので、履歴の直近ウィンドウ（SessionRecentWindow）では絞らない
		let sessions = try modelContext.fetch(FetchDescriptor<SingingSession>())
		let sessionsByTrackId = Dictionary(grouping: sessions) { $0.track.id }

		return sessionsByTrackId.values.compactMap { trackSessions in
			// 歌唱日時が同じ記録が並んだときも結果が変わらないよう、id でも比べる
			guard let latest = trackSessions.max(by: { a, b in
				if a.performedAt != b.performedAt { return a.performedAt < b.performedAt }
				return a.id.uuidString < b.id.uuidString
			}) else { return nil }
			let track = latest.track
			return TrackSingingStats(
				trackId: track.id,
				spotifyTrackId: track.spotifyTrackId,
				userEnteredName: track.userEnteredName,
				latestIntent: latest.intent,
				lastPerformedAt: latest.performedAt,
				bestScore: trackSessions.compactMap(\.score).max(),
				sessionCount: trackSessions.count,
				latestWantAgain: latest.wantAgain
			)
		}
	}
}
