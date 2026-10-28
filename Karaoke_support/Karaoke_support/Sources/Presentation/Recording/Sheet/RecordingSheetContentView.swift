import Observation
import SwiftUI
import UIKit

struct RecordingSheetContentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(NetworkMonitor.self) private var networkMonitor

    @Bindable var viewModel: RecordingSheetViewModel
    let onSaved: (SavedRecording) -> Void

    /// 点数のテンキーを出している間は、保存の帯の代わりに「完了」を出す（#137）。
    /// キーボードのツールバーで出すと、そのあと曲名のキーボードを出したときに保存の帯がキーボードに重なるため。
    @FocusState private var isScoreFocused: Bool

    private var recordingTitle: String {
        viewModel.isEditingExistingSession ? "記録を編集" : "記録を追加"
    }

    var body: some View {
        ZStack {
            AppBackgroundGradientView()

            let isRetrying = viewModel.inlineErrorMessage != nil
            let trackSectionDisabled = isRetrying || viewModel.isTrackInputLockedForEdit

            ScrollView {
                VStack(spacing: 16) {
                    SheetHeaderView(
                        title: recordingTitle,
                        isDisabled: viewModel.isSaving,
                        confirmsDiscard: viewModel.hasUnsavedChanges
                    ) {
                        dismiss()
                    }

                    if let originalPerformedAt = viewModel.editingSessionOriginalPerformedAt {
                        RecordingEditingBannerView(originalPerformedAt: originalPerformedAt)
                    }

                    if !networkMonitor.isOnline {
                        OfflineBannerView(
                            onOpenSettings: openAppSettings,
                            onRetry: { networkMonitor.refreshStatus() }
                        )
                    }

                    TrackInputSectionView(
                        state: $viewModel.trackState,
                        isDisabled: trackSectionDisabled,
                        focusesOnAppear: viewModel.focusesTrackNameOnOpen,
                        isLockedForEdit: viewModel.isTrackInputLockedForEdit,
                        suggestionState: trackSectionDisabled ? .hidden : viewModel.trackSuggestionState,
                        isSuggestionStale: viewModel.isTrackSuggestionStale,
                        onSelectSuggestion: viewModel.applyTrackSuggestion
                    )
                    .task(id: viewModel.trackState.manualName) {
                        await viewModel.updateTrackSuggestions(for: viewModel.trackState.manualName)
                    }
                    RecordingSheetScoreSection(
                        score: $viewModel.draft.score,
                        isDisabled: isRetrying,
                        isFocused: $isScoreFocused
                    )
                    RecordingSheetIntentSection(
                        intent: $viewModel.draft.intent,
                        isDisabled: isRetrying
                    )
                    RecordingSheetCompletionSection(
                        isCompleted: $viewModel.draft.isCompleted,
                        isDisabled: isRetrying
                    )
                    // 新規記録の歌唱日時は保存した時刻を自動で入れる。直せるのは履歴からの編集のときだけ
                    if viewModel.isEditingExistingSession {
                        RecordingSheetPerformedAtSection(
                            performedAt: $viewModel.draft.performedAt,
                            isDisabled: isRetrying
                        )
                    }
                    RecordingSheetMemoSection(
                        memo: $viewModel.draft.memo,
                        placeholder: viewModel.memoPlaceholder,
                        isDisabled: isRetrying
                    )

                    if let msg = viewModel.inlineErrorMessage {
                        InlineErrorRetryView(
                            message: msg,
                            retryTitle: "再試行",
                            onRetry: { Task { await attemptSave() } }
                        )
                    }

                    Spacer(minLength: 88)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                // 「もしかして」欄の出入りで下のセクションが跳ねないように
                .animation(.easeInOut(duration: 0.2), value: viewModel.trackSuggestionState)
            }

            if viewModel.isSaving {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                ProgressView()
                    .padding(20)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isScoreFocused {
                scoreDoneBar
            } else {
                bottomCTA
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving || viewModel.hasUnsavedChanges)

    }

    private var bottomCTA: some View {
        HStack(spacing: 12) {
            RecordingSheetWantAgainButton(
                isOn: $viewModel.draft.wantAgain,
                isDisabled: viewModel.isSaving || viewModel.inlineErrorMessage != nil
            )
            .zIndex(1)

            Button {
                Task { await attemptSave() }
            } label: {
                HStack {
                    Image(systemName: saveButtonSystemImage)
                    Text(saveButtonTitle)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.accentScore)
            .disabled(viewModel.isSaving)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var scoreDoneBar: some View {
        HStack {
            Spacer()
            Button("完了") { isScoreFocused = false }
                .font(.headline)
                .buttonStyle(.glass)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// 編集では今の記録を書き換えるので、新規の「保存」と区別して「更新」と出す。
    private var saveButtonTitle: String {
        if viewModel.isEditingExistingSession {
            return viewModel.isSaving ? "更新中..." : "更新する"
        }
        return viewModel.isSaving ? "保存中..." : "保存する"
    }

    private var saveButtonSystemImage: String {
        viewModel.isEditingExistingSession ? "checkmark" : "tray.and.arrow.down.fill"
    }

    @MainActor
    private func attemptSave() async {
        guard let saved = await viewModel.save() else { return }
        onSaved(saved)
        dismiss()
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#Preview {
    RecordingSheetContentView(
        viewModel: RecordingSheetViewModel(
            trackMode: .manual,
            sessionRepository: PreviewSessionRepository(),
            trackRepository: PreviewTrackRepository()
        ),
        onSaved: { _ in }
    )
    .environment(NetworkMonitor(startsMonitoring: false))
}
