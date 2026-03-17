import SwiftUI
import SwiftData

@main
struct KaraokeSupportApp: App {
	@State private var networkMonitor = NetworkMonitor()

	var body: some Scene {
		WindowGroup {
			RootView()
				.environment(\.networkMonitor, networkMonitor)
		}
		.modelContainer(for: [Track.self, SingingSession.self])
	}
}