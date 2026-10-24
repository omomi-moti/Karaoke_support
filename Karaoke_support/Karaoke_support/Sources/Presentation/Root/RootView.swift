import SwiftUI

struct RootView: View {
    enum RootTab: Hashable {
        case songs
        case history
        case settings
        case search
    }

    /// `RootView` に 1 つだけ置くシートの中身。記録シートと保存直後のシートをここで切り替える（ADR 0025）。
    private struct RootSheet: Identifiable {
        enum Kind {
            case recording(RecordingSessionSeed)
            case afterSave(AfterSaveSheetContent)
        }

        let id = UUID()
        let kind: Kind
    }

    @Environment(\.trackRepository) private var trackRepository
    @Environment(\.trackStatsRepository) private var trackStatsRepository

    @State private var selectedTab: RootTab = .songs
    @State private var sheet: RootSheet?
    /// 今のシートが閉じ終わってから出すシート。閉じている途中に次のシートを出すと、SwiftUI が出し損ねることがあるため。
    @State private var pendingSheet: RootSheet?
    /// シートを閉じ始めてから、閉じ終わる（`onDismiss`）までの間 `true`。
    @State private var isDismissingSheet = false
    @State private var afterSaveViewModel: AfterSaveRecommendationViewModel?
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
                .padding(.trailing, AddRecordingButtonMetrics.margin)
                .padding(.bottom, tabBarInset + AddRecordingButtonMetrics.margin)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .ignoresSafeArea()
                .opacity(isAddButtonVisible ? 1 : 0)
                .allowsHitTesting(isAddButtonVisible)
                .accessibilityHidden(!isAddButtonVisible)
        }
        .sheet(item: $sheet, onDismiss: presentPendingSheet) { sheet in
            switch sheet.kind {
            case .recording(let seed):
                RecordingSheetContainerView(seed: seed, onSavedMoveToHistory: handleSaved)
            case .afterSave(let content):
                AfterSaveRecommendationSheetView(
                    content: content,
                    onSelect: { recordRecommendation($0, intent: content.saved.intent) },
                    onLater: { closeSheet() }
                )
            }
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
        present(.recording(.mode(.manual)))
    }

    private func presentRecording(_ selected: SelectedTrack) {
        present(.recording(.selectedTrack(selected)))
    }

    private func presentEditRecording(_ sessionId: UUID) {
        present(.recording(.editSession(sessionId: sessionId)))
    }

    /// 保存したら記録シートを閉じて履歴へ移り、候補があれば保存直後のシートを出す（#115）。
    private func handleSaved(_ saved: SavedRecording) {
        closeSheet()
        historyReloadTick += 1
        moveToHistory()
        let viewModel = afterSaveRecommendationViewModel()
        Task {
            guard let content = await viewModel.prepare(for: saved) else { return }
            present(.afterSave(content))
        }
    }

    /// 提案のカードから、その曲と保存した記録の気分を入れて記録シートを開く。
    private func recordRecommendation(_ recommendation: TrackRecommendation, intent: Intent) {
        guard let selected = SelectedTrack(
            spotifyTrackId: recommendation.stats.spotifyTrackId,
            userEnteredName: recommendation.stats.userEnteredName
        ) else { return }
        closeSheet(then: .recording(.selectedTrack(selected, intent: intent)))
    }

    private func present(_ kind: RootSheet.Kind) {
        if isDismissingSheet {
            pendingSheet = RootSheet(kind: kind)
        } else if sheet != nil {
            closeSheet(then: kind)
        } else {
            sheet = RootSheet(kind: kind)
        }
    }

    /// 今のシートを閉じる。`next` を渡すと、閉じ終わってから出す。
    private func closeSheet(then next: RootSheet.Kind? = nil) {
        pendingSheet = next.map { RootSheet(kind: $0) }
        guard sheet != nil else {
            presentPendingSheet()
            return
        }
        isDismissingSheet = true
        sheet = nil
    }

    /// シートが閉じ終わったとき（`onDismiss`）に呼ぶ。下に引いて閉じたときも呼ばれる。
    private func presentPendingSheet() {
        isDismissingSheet = false
        guard let next = pendingSheet else { return }
        pendingSheet = nil
        sheet = next
    }

    private func afterSaveRecommendationViewModel() -> AfterSaveRecommendationViewModel {
        if let afterSaveViewModel { return afterSaveViewModel }
        let viewModel = AfterSaveRecommendationViewModel(trackStatsRepository: trackStatsRepository)
        afterSaveViewModel = viewModel
        return viewModel
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
                .frame(width: AddRecordingButtonMetrics.size, height: AddRecordingButtonMetrics.size)
        }
        .buttonStyle(.glassProminent)
        .tint(AppColor.addButton)
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
