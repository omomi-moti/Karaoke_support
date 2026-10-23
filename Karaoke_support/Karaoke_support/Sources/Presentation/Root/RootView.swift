import SwiftUI

struct RootView: View {
    enum RootTab: Hashable {
        case songs
        case history
        case settings
        case search
    }

    private struct RecordingSheetItem: Identifiable {
        let id = UUID()
        let seed: RecordingSessionSeed
    }

    @Environment(\.trackRepository) private var trackRepository

    @State private var selectedTab: RootTab = .songs
    @State private var recordingSheetItem: RecordingSheetItem?
    /// 保存のたびに増やし、履歴一覧に再読み込みさせる（履歴タブ上で保存するとタブ切替による再表示が起きないため）。
    @State private var historyReloadTick = 0
    /// タブの中身の下の安全領域（タブバー＋ホームインジケーター）。＋ボタンをタブバーの上に置くのに使う。
    @State private var tabBarInset: CGFloat = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("選曲", systemImage: "music.note.list", value: .songs) {
                SongsRootView(onSelectTrack: presentRecording)
                    .modifier(TabBarInsetReader(inset: $tabBarInset))
            }

            Tab("履歴", systemImage: "clock", value: .history) {
                HistoryRootView()
                    .modifier(TabBarInsetReader(inset: $tabBarInset))
            }

            Tab("設定", systemImage: "gearshape", value: .settings) {
                NavigationStack {
                    SettingsRootView()
                }
            }

            Tab(value: .search, role: .search) {
                NavigationStack {
                    SearchContainerView(
                        trackRepository: trackRepository,
                        onSelectTrack: presentRecording
                    )
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .overlay {
            AddRecordingButton(action: presentManualRecording)
                .padding(.trailing, 16)
                .padding(.bottom, tabBarInset + 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .ignoresSafeArea()
                .opacity(isAddButtonVisible ? 1 : 0)
                .allowsHitTesting(isAddButtonVisible)
                .accessibilityHidden(!isAddButtonVisible)
        }
        .sheet(item: $recordingSheetItem) { item in
            RecordingSheetContainerView(
                seed: item.seed,
                onSavedMoveToHistory: {
                    recordingSheetItem = nil
                    historyReloadTick += 1
                    moveToHistory()
                }
            )
        }
        .environment(\.navigateToManualRecording, presentManualRecording)
        .environment(\.navigateToEditRecording, presentEditRecording)
        .environment(\.historyReloadTick, historyReloadTick)
    }

    /// ＋は選曲・履歴タブだけに出す（R2）。外さずに透明にして、同じボタンを居続けさせる（R5）。
    /// タブバーの高さを測るまでは、位置が決まらないので出さない。
    private var isAddButtonVisible: Bool {
        (selectedTab == .songs || selectedTab == .history) && tabBarInset > 0
    }

    private func presentManualRecording() {
        recordingSheetItem = RecordingSheetItem(seed: .mode(.manual))
    }

    private func presentRecording(_ selected: SelectedTrack) {
        recordingSheetItem = RecordingSheetItem(seed: .selectedTrack(selected))
    }

    private func presentEditRecording(_ sessionId: UUID) {
        recordingSheetItem = RecordingSheetItem(seed: .editSession(sessionId: sessionId))
    }

    private func moveToHistory() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedTab = .history
        }
    }
}

private struct AddRecordingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .accessibilityLabel("手動で記録")
    }
}

/// タブの中身の下の安全領域を測って `inset` に入れる。キーボードの分は含めない。
private struct TabBarInsetReader: ViewModifier {
    @Binding var inset: CGFloat

    func body(content: Content) -> some View {
        content.background {
            Color.clear
                .ignoresSafeArea(.keyboard)
                .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { inset = $0 }
        }
    }
}

#Preview {
    RootView()
        .environment(\.networkMonitor, NetworkMonitor(startsMonitoring: false))
        .environment(\.trackRepository, PreviewTrackRepository())
        .environment(\.insightRepository, PreviewInsightRepository())
        .environment(\.sessionRepository, PreviewSessionRepository())
}
