import SwiftUI

struct RootView: View {
	var body: some View {
		TabView {
			NavigationStack {
				SongsRootView()
			}
			.tabItem {
				Label("選曲", systemImage: "music.note.list")
			}

			NavigationStack {
				HistoryRootView()
			}
			.tabItem {
				Label("履歴", systemImage: "clock")
			}

			NavigationStack {
				SettingsRootView()
			}
			.tabItem {
				Label("設定", systemImage: "gearshape")
			}
		}
	}
}

#Preview {
	RootView()
}