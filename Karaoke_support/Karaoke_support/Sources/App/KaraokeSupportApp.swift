import SwiftUI
import SwiftData

@main
struct KaraokeSupportApp: App {
	var body: some Scene {
		WindowGroup {
			RootView()
		}
		.modelContainer(for: [Track.self, SingingSession.self])
	}
}