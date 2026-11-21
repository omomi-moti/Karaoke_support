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

    /// 記録シートが閉じ終わってから保存直後のシートを出すまでの時間。保存した記録が画面に増えたのが見えてから出すため（ADR 0070）。
    private static let afterSaveSheetDelay: Duration = .milliseconds(1000)
    /// 「保存しました」を出しておく時間。
    private static let savedToastDuration: Duration = .seconds(2)

    @Environment(\.trackRepository) private var trackRepository
    @Environment(\.trackStatsRepository) private var trackStatsRepository
    #if DEBUG || BETA
    @Environment(\.accountRepository) private var accountRepository
    #endif

    @State private var selectedTab: RootTab = .songs
    @State private var sheet: RootSheet?
    /// 今のシートが閉じ終わってから出すシート。閉じている途中に次のシートを出すと、SwiftUI が出し損ねることがあるため。
    @State private var pendingSheet: RootSheet?
    /// シートを閉じ始めてから、閉じ終わる（`onDismiss`）までの間 `true`。
    @State private var isDismissingSheet = false
    @State private var afterSaveViewModel: AfterSaveRecommendationViewModel?
    /// 保存してから、記録シートが閉じ終わるまでの間 `true`。閉じ終わったら、保存直後のシートを出す時刻を決める。タブは移さない（ADR 0070）。
    @State private var isClosingSavedRecording = false
    /// 保存したあと、記録シートが閉じ終わったら `true`。「保存しました」は、これと ``isSavedToastNeeded`` がそろってから出す。
    @State private var hasClosedSavedRecording = false
    /// 保存直後のシートを出さないと決まったら `true`（履歴タブ以外・候補が 0 件・編集・読み込みの失敗）。シートの見出しが「保存しました」なので、出すときは重ねない（ADR 0070）。
    @State private var isSavedToastNeeded = false
    /// 保存のたびに増やす。前の保存の候補の読み込みが遅れて終わっても、今の保存の「保存しました」を決めないため。
    @State private var saveGeneration = 0
    /// 読み込み終わった保存直後のシートの中身。記録シートが閉じ終わってから出す。
    @State private var preparedAfterSaveContent: AfterSaveSheetContent?
    /// 保存直後のシートを出してよい時刻（記録シートが閉じ終わってから ``afterSaveSheetDelay`` 後）。
    @State private var afterSaveShowAt: ContinuousClock.Instant?
    @State private var isSavedToastVisible = false
    /// 「保存しました」を出すたびに増やす。続けて保存したとき、前の分の時間切れで今の表示を消さないため。
    @State private var savedToastGeneration = 0
    /// 保存のたびに増やし、履歴一覧に再読み込みさせる（履歴タブ上で保存するとタブ切替による再表示が起きないため）。
    @State private var historyReloadTick = 0
    /// タブの中身の下の安全領域（タブバー＋ホームインジケーター）。＋ボタンをタブバーの上に置くのに使う。
    @State private var tabBarInset: CGFloat = 0
    /// 履歴タブの画面の積み方。＋を押したときに、曲詳細を開いているかを読む（ADR 0047）。
    @State private var historyPath: [HistoryRoute] = []

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("選曲", systemImage: "music.note.list", value: .songs) {
                SongsRootView(onSelect: recordFromSelectionScreen)
                    .modifier(TabBarInsetReader(inset: $tabBarInset))
            }

            Tab("履歴", systemImage: "clock", value: .history) {
                HistoryRootView(navigationPath: $historyPath)
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
                        trackStatsRepository: trackStatsRepository,
                        onSelectTrack: presentRecording
                    )
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .overlay {
            AddRecordingButton(
                accessibilityLabel: trackOnScreen == nil ? "手動で記録" : "この曲を記録",
                action: presentAddRecording
            )
                .padding(.trailing, AddRecordingButtonMetrics.margin)
                .padding(.bottom, tabBarInset + AddRecordingButtonMetrics.margin)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .ignoresSafeArea()
                .opacity(isAddButtonVisible ? 1 : 0)
                .allowsHitTesting(isAddButtonVisible)
                .accessibilityHidden(!isAddButtonVisible)
        }
        .overlay(alignment: .top) {
            if isSavedToastVisible {
                SavedToastView()
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: $sheet, onDismiss: presentPendingSheet) { sheet in
            switch sheet.kind {
            case .recording(let seed):
                RecordingSheetContainerView(seed: seed, onSaved: handleSaved)
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
        .environment(\.notifyRecordsChanged) { historyReloadTick += 1 }
        .environment(\.historyReloadTick, historyReloadTick)
        .environment(\.isRestoreHintVisible, isRestoreHintVisible)
    }

    /// アカウントの欄があるときだけ、空の画面で取り込みを案内する（ADR 0061・0070）。
    private var isRestoreHintVisible: Bool {
        #if DEBUG || BETA
        accountRepository != nil
        #else
        false
        #endif
    }

    /// ＋は選曲・履歴タブだけに出す（R2）。外さずに透明にして、同じボタンを居続けさせる（R5）。
    /// タブバーの高さを測るまでは、位置が決まらないので出さない。
    private var isAddButtonVisible: Bool {
        (selectedTab == .songs || selectedTab == .history) && tabBarInset > 0
    }

    /// 履歴タブで曲詳細を開いているときの曲。ほかの画面では `nil`。
    private var trackOnScreen: SelectedTrack? {
        guard selectedTab == .history, case .trackDetail(_, let title, let artistName)? = historyPath.last else { return nil }
        return SelectedTrack(spotifyTrackId: nil, userEnteredName: title, userEnteredArtistName: artistName)
    }

    /// ＋は、曲詳細ではその曲名を入れて、ほかの画面では空で記録シートを開く（ADR 0047）。
    private func presentAddRecording() {
        if let trackOnScreen {
            presentRecording(trackOnScreen)
        } else {
            presentManualRecording()
        }
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

    /// 保存したら記録シートを閉じ、今のタブのまま、候補があれば保存直後のシートを出す（#115、ADR 0070）。
    /// 出すのは履歴タブで保存したときだけ。選曲タブでは後ろの選曲画面がそのまま次の曲の候補になり、検索タブでは歌う曲がもう決まっているため。
    private func handleSaved(_ saved: SavedRecording) {
        // 前の保存のときの中身や時刻が残っていても使わない
        preparedAfterSaveContent = nil
        afterSaveShowAt = nil
        hasClosedSavedRecording = false
        isSavedToastNeeded = false
        saveGeneration += 1
        let generation = saveGeneration
        isClosingSavedRecording = true
        closeSheet()
        historyReloadTick += 1
        guard selectedTab == .history else {
            isSavedToastNeeded = true
            return
        }
        let viewModel = afterSaveRecommendationViewModel()
        Task {
            guard let content = await viewModel.prepare(for: saved) else {
                guard generation == saveGeneration else { return }
                isSavedToastNeeded = true
                showSavedToastWhenReady()
                return
            }
            preparedAfterSaveContent = content
            presentAfterSaveSheetWhenReady()
        }
    }

    /// 中身の読み込みと記録シートを閉じ終わるのが両方そろったら、決めた時刻まで待って保存直後のシートを出す。どちらが先に終わってもよい。
    private func presentAfterSaveSheetWhenReady() {
        guard let content = preparedAfterSaveContent, let showAt = afterSaveShowAt else { return }
        preparedAfterSaveContent = nil
        afterSaveShowAt = nil
        Task {
            try? await Task.sleep(until: showAt, clock: .continuous)
            // 待っている間に別のシートを開いた・開こうとしているなら、そちらを優先する（入力中の記録シートを閉じない）
            guard sheet == nil, pendingSheet == nil else { return }
            present(.afterSave(content))
        }
    }

    /// 提案のカードから、その曲と保存した記録の気分を入れて記録シートを開く。曲を変えずに保存すると、提案からの記録になる（#120）。
    private func recordRecommendation(_ recommendation: TrackRecommendation, intent: Intent) {
        guard let selected = SelectedTrack(
            spotifyTrackId: recommendation.stats.spotifyTrackId,
            userEnteredName: recommendation.stats.userEnteredName,
            userEnteredArtistName: recommendation.stats.userEnteredArtistName
        ) else { return }
        closeSheet(then: .recording(.selectedTrack(selected, intent: intent, source: .suggestion)))
    }

    /// 選曲画面のカードから、その曲と選んでいる気分を入れて記録シートを開く。曲を変えずに保存すると、選曲画面からの記録になる（#126）。
    private func recordFromSelectionScreen(_ recommendation: TrackRecommendation, intent: Intent) {
        guard let selected = SelectedTrack(
            spotifyTrackId: recommendation.stats.spotifyTrackId,
            userEnteredName: recommendation.stats.userEnteredName,
            userEnteredArtistName: recommendation.stats.userEnteredArtistName
        ) else { return }
        present(.recording(.selectedTrack(selected, intent: intent, source: .selectionScreen)))
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
            // 閉じている途中（カードの二度押しなど）は予約だけして、閉じ終わってから出す
            if !isDismissingSheet {
                presentPendingSheet()
            }
            return
        }
        isDismissingSheet = true
        sheet = nil
    }

    /// シートが閉じ終わったとき（`onDismiss`）に呼ぶ。下に引いて閉じたときも呼ばれる。
    private func presentPendingSheet() {
        isDismissingSheet = false
        if isClosingSavedRecording {
            isClosingSavedRecording = false
            hasClosedSavedRecording = true
            showSavedToastWhenReady()
            afterSaveShowAt = ContinuousClock.now + Self.afterSaveSheetDelay
            presentAfterSaveSheetWhenReady()
        }
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

    /// 保存直後のシートを出さないと決まり、記録シートも閉じ終わったら「保存しました」を出す。どちらが先でもよい。
    private func showSavedToastWhenReady() {
        guard isSavedToastNeeded, hasClosedSavedRecording else { return }
        isSavedToastNeeded = false
        showSavedToast()
    }

    private func showSavedToast() {
        savedToastGeneration += 1
        let generation = savedToastGeneration
        withAnimation { isSavedToastVisible = true }
        AccessibilityNotification.Announcement("保存しました").post()
        Task {
            try? await Task.sleep(for: Self.savedToastDuration)
            guard generation == savedToastGeneration else { return }
            withAnimation { isSavedToastVisible = false }
        }
    }
}

private struct AddRecordingButton: View {
    let accessibilityLabel: String
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
        .accessibilityLabel(accessibilityLabel)
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
        .environment(NetworkMonitor(startsMonitoring: false))
        .environment(\.trackRepository, PreviewTrackRepository())
        .environment(\.insightRepository, PreviewInsightRepository())
        .environment(\.sessionRepository, PreviewSessionRepository())
}
