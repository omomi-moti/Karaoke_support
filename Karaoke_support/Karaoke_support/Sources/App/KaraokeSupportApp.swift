import SwiftUI
import SwiftData

@main
struct KaraokeSupportApp: App {
	private let dependencies: AppDependencies
	@State private var networkMonitor = NetworkMonitor()

	@MainActor
	init() {
		// UI テストは `Karaoke_supportUITestsLaunchTests` 等から `launchEnvironment` で有効化。永続ストア起因の起動クラッシュを避ける。
		if ProcessInfo.processInfo.environment["KARAOKE_UITEST_IN_MEMORY"] == "1" {
			do {
				self.dependencies = try AppDependencies.make(configuration: ModelConfiguration(isStoredInMemoryOnly: true))
			} catch {
				fatalError("Failed to create in-memory ModelContainer for UI tests: \(error)")
			}
			return
		}

		do {
			self.dependencies = try AppDependencies.make(configuration: ModelConfiguration(isStoredInMemoryOnly: false))
		} catch {
			assertionFailure("Failed to create persistent ModelContainer: \(error). Falling back to in-memory store.")
			do {
				self.dependencies = try AppDependencies.make(configuration: ModelConfiguration(isStoredInMemoryOnly: true))
			} catch {
				fatalError("Failed to create in-memory ModelContainer: \(error)")
			}
		}
	}

	var body: some Scene {
		WindowGroup {
			RootView()
				.environment(networkMonitor)
				.environment(\.sessionRepository, dependencies.sessionRepository)
				.environment(\.trackRepository, dependencies.trackRepository)
				.environment(\.insightRepository, dependencies.insightRepository)
				.environment(\.trackStatsRepository, dependencies.trackStatsRepository)
		}
		.modelContainer(dependencies.modelContainer)
	}
}
