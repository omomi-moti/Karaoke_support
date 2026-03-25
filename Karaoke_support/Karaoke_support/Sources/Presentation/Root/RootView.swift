import SwiftUI

struct RootView: View {
	enum RootTab: Hashable {
		case songs
		case history
		case settings
	}

	@State private var selectedTab: RootTab = .songs
	/// 履歴から手動記録へ遷移するたびに増やし、``SongsRootView`` が記録シートを開く（I-016）。
	@State private var manualRecordingNavigationTick: Int = 0

	var body: some View {
		TabView(selection: $selectedTab) {
			/// 選曲タブの `NavigationStack` は `SongsRootView` 内のみ（二重スタック回避・I-013）。
			SongsRootView(
				onSavedMoveToHistory: {
					var transaction = Transaction()
					transaction.disablesAnimations = true
					withTransaction(transaction) {
						selectedTab = .history
					}
				},
				manualRecordingNavigationTick: $manualRecordingNavigationTick
			)
			.tabItem {
				Label("選曲", systemImage: "music.note.list")
			}
			.tag(RootTab.songs)

			/// ナビゲーションは ``HistoryListContainerView`` 内の `NavigationStack` に集約（履歴→編集の push を含む・I-014-C）。
			HistoryRootView()
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
		.environment(\.navigateToManualRecording) {
			selectedTab = .songs
			manualRecordingNavigationTick += 1
		}
	}
}

#Preview {
	RootView()
}