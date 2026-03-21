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
			/// 選曲タブの `NavigationStack` は `SongsRootView` 内のみ（二重スタック回避・I-013）。
			SongsRootView(
				onSavedMoveToHistory: {
					selectedTab = .history
				}
			)
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