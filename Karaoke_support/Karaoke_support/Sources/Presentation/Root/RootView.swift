import SwiftUI

struct RootView: View {
	enum RootTab: Hashable {
		case songs
		case history
		case settings
	}

	@State private var selectedTab: RootTab = .songs

	var body: some View {
		TabView(selection: $selectedTab) {
			NavigationStack {
				SongsRootView(
					onSavedMoveToHistory: {
						selectedTab = .history
					}
				)
			}
			.tabItem {
				Label("選曲", systemImage: "music.note.list")
			}
			.tag(RootTab.songs)

			NavigationStack {
				HistoryRootView()
			}
			.tabItem {
				Label("履歴", systemImage: "clock")
			}
			.tag(RootTab.history)

			NavigationStack {
				SettingsRootView()
			}
			.tabItem {
				Label("設定", systemImage: "gearshape")
			}
			.tag(RootTab.settings)
		}
	}
}

#Preview {
	RootView()
}