import Foundation

@MainActor
final class PreviewInsightRepository: InsightRepositoryProtocol {
	func fetchTimeMachineRanking() async throws -> [InsightTrackCountRanking] {
		[]
	}

	func fetchMyAnthemRankings(period: InsightPeriod) async throws -> [MyAnthemRanking] {
		[]
	}
}

