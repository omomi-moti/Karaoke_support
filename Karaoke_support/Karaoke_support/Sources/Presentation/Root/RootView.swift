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

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("選曲", systemImage: "music.note.list", value: .songs) {
                SongsRootView(onSelectTrack: presentRecording)
                    .modifier(AddRecordingButton(action: presentManualRecording))
            }

            Tab("履歴", systemImage: "clock", value: .history) {
                HistoryRootView()
                    .modifier(AddRecordingButton(action: presentManualRecording))
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
        .modifier(MinimizeOnScroll())
        .sheet(item: $recordingSheetItem) { item in
            RecordingSheetContainerView(
                seed: item.seed,
                onSavedMoveToHistory: {
                    recordingSheetItem = nil
                    moveToHistory()
                }
            )
        }
        .environment(\.navigateToManualRecording, presentManualRecording)
    }

    private func presentManualRecording() {
        recordingSheetItem = RecordingSheetItem(seed: .mode(.manual))
    }

    private func presentRecording(_ selected: SelectedTrack) {
        recordingSheetItem = RecordingSheetItem(seed: .selectedTrack(selected))
    }

    private func moveToHistory() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedTab = .history
        }
    }
}

private struct AddRecordingButton: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                Button(action: action) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 48, height: 48)
                }
                .modifier(FloatingButtonStyle())
                .accessibilityLabel("手動で記録")
                .padding(16)
            }
    }
}

private struct MinimizeOnScroll: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

private struct FloatingButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
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
