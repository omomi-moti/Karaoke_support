import SwiftUI
import SwiftData

@main
struct KaraokeSupportApp: App {
	private let modelContainer: ModelContainer
	private let sessionRepository: any SessionRepositoryProtocol
	private let trackRepository: any TrackRepositoryProtocol
	private let insightRepository: any InsightRepositoryProtocol
	@State private var networkMonitor = NetworkMonitor()

	@MainActor
	init() {
		do {
			let container = try ModelContainer(for: Track.self, SingingSession.self)
			self.modelContainer = container

			let context = container.mainContext
			self.sessionRepository = SwiftDataSessionRepository(modelContext: context)
			self.trackRepository = SwiftDataTrackRepository(modelContext: context)
			self.insightRepository = SwiftDataInsightRepository(modelContext: context)
		} catch {
			fatalError("Failed to create ModelContainer: \(error)")
		}
	}

	var body: some Scene {
		WindowGroup {
			RootView()
				.environment(\.networkMonitor, networkMonitor)
				.environment(\.sessionRepository, sessionRepository)
				.environment(\.trackRepository, trackRepository)
				.environment(\.insightRepository, insightRepository)
		}
		.modelContainer(modelContainer)
	}
}