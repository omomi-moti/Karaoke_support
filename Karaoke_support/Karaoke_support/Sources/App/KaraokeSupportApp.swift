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
		// UI テストは `Karaoke_supportUITestsLaunchTests` 等から `launchEnvironment` で有効化。永続ストア起因の起動クラッシュを避ける。
		if ProcessInfo.processInfo.environment["KARAOKE_UITEST_IN_MEMORY"] == "1" {
			do {
				let container = try Self.makeModelContainer(isInMemory: true)
				self.modelContainer = container
			} catch {
				fatalError("Failed to create in-memory ModelContainer for UI tests: \(error)")
			}
			let context = modelContainer.mainContext
			self.sessionRepository = SwiftDataSessionRepository(modelContext: context)
			self.trackRepository = SwiftDataTrackRepository(modelContext: context)
			self.insightRepository = SwiftDataInsightRepository(modelContext: context)
			return
		}

		do {
			let container = try Self.makeModelContainer(isInMemory: false)
			self.modelContainer = container
		} catch {
			assertionFailure("Failed to create persistent ModelContainer: \(error). Falling back to in-memory store.")
			do {
				self.modelContainer = try Self.makeModelContainer(isInMemory: true)
			} catch {
				fatalError("Failed to create in-memory ModelContainer: \(error)")
			}
		}

		let context = modelContainer.mainContext
		self.sessionRepository = SwiftDataSessionRepository(modelContext: context)
		self.trackRepository = SwiftDataTrackRepository(modelContext: context)
		self.insightRepository = SwiftDataInsightRepository(modelContext: context)
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

	@MainActor
	private static func makeModelContainer(isInMemory: Bool) throws -> ModelContainer {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: isInMemory)
		return try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
	}
}
