import SwiftData

/// アプリが起動時に作る依存（DB と Repository）。作るのは ``make(configuration:)`` の 1 か所にまとめる（#119）。
@MainActor
struct AppDependencies {
	let modelContainer: ModelContainer
	let sessionRepository: any SessionRepositoryProtocol
	let trackRepository: any TrackRepositoryProtocol
	let insightRepository: any InsightRepositoryProtocol
	let trackStatsRepository: any TrackStatsRepositoryProtocol

	/// DB を開き、Repository を作る。DB を開けなければ throw する。
	static func make(configuration: ModelConfiguration) throws -> AppDependencies {
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		let context = container.mainContext
		return AppDependencies(
			modelContainer: container,
			sessionRepository: SwiftDataSessionRepository(modelContext: context),
			trackRepository: SwiftDataTrackRepository(modelContext: context),
			insightRepository: SwiftDataInsightRepository(modelContext: context),
			trackStatsRepository: SwiftDataTrackStatsRepository(modelContext: context)
		)
	}
}
