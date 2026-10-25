import OSLog
import SwiftUI
import SwiftData

@main
struct KaraokeSupportApp: App {
	/// 保存先の DB を開けなかったときは失敗のまま持ち、メモリ上の DB では起動しない（ADR 0033）。
	private let dependencies: Result<AppDependencies, any Error>
	@State private var networkMonitor = NetworkMonitor()

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Karaoke_support", category: "DataStore")

	@MainActor
	init() {
		// UI テストは `Karaoke_supportUITestsLaunchTests` 等から `launchEnvironment` で有効化。永続ストア起因の起動クラッシュを避ける。
		if ProcessInfo.processInfo.environment["KARAOKE_UITEST_IN_MEMORY"] == "1" {
			do {
				self.dependencies = .success(try AppDependencies.make(configuration: ModelConfiguration(isStoredInMemoryOnly: true)))
			} catch {
				fatalError("Failed to create in-memory ModelContainer for UI tests: \(error)")
			}
			return
		}

		#if DEBUG
		// エラー画面を確かめるためだけに、DB を開けなかったことにする（デバッグのビルドだけ）。
		if ProcessInfo.processInfo.environment["KARAOKE_SIMULATE_DATA_LOAD_FAILURE"] == "1" {
			self.dependencies = .failure(SimulatedDataLoadFailure())
			return
		}
		#endif

		do {
			self.dependencies = .success(try AppDependencies.make(configuration: ModelConfiguration(isStoredInMemoryOnly: false)))
		} catch {
			// 元のデータには手を付けず、原因を追えるようにログだけ残す
			Self.logger.error("Failed to open the persistent store: \(String(describing: error), privacy: .public)")
			self.dependencies = .failure(error)
		}
	}

	var body: some Scene {
		WindowGroup {
			switch dependencies {
			case .success(let dependencies):
				RootView()
					.environment(networkMonitor)
					.environment(\.sessionRepository, dependencies.sessionRepository)
					.environment(\.trackRepository, dependencies.trackRepository)
					.environment(\.insightRepository, dependencies.insightRepository)
					.environment(\.trackStatsRepository, dependencies.trackStatsRepository)
					.modelContainer(dependencies.modelContainer)
			case .failure:
				DataLoadErrorView()
			}
		}
	}
}

#if DEBUG
private struct SimulatedDataLoadFailure: Error {}
#endif
