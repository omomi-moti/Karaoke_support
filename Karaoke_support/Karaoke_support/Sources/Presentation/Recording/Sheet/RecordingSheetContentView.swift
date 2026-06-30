import Observation
import SwiftUI
import UIKit

struct RecordingSheetContentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.networkMonitor) private var networkMonitor

    @Bindable var viewModel: RecordingSheetViewModel
    let presentation: RecordingContentPresentation
    let onSavedMoveToHistory: () -> Void

    private var recordingTitle: String {
        viewModel.isEditingExistingSession ? "記録を編集" : "記録を追加"
    }

    var body: some View {
        ZStack {
            let isRetrying = viewModel.inlineErrorMessage != nil
            let trackSectionDisabled = isRetrying || viewModel.isTrackInputLockedForEdit

            ScrollView {
                VStack(spacing: 16) {
                    if presentation == .sheet {
                        SheetHeaderView(title: recordingTitle, isDisabled: viewModel.isSaving) {
                            dismiss()
                        }
                    }

                    if !networkMonitor.isOnline {
                        OfflineBannerView(
                            onOpenSettings: openAppSettings,
                            onRetry: { networkMonitor.refreshStatus() }
                        )
                    }

                    TrackInputSectionView(
                        state: $viewModel.trackState,
                        isDisabled: trackSectionDisabled
                    )
                    RecordingSheetScoreSection(
                        score: $viewModel.draft.score,
                        isDisabled: isRetrying
                    )
                    RecordingSheetIntentSection(
                        intent: $viewModel.draft.intent,
                        isDisabled: isRetrying
                    )
                    RecordingSheetPerformedAtSection(
                        performedAt: $viewModel.draft.performedAt,
                        isDisabled: isRetrying
                    )
                    RecordingSheetMemoSection(
                        memo: $viewModel.draft.memo,
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
            }

            if viewModel.isSaving {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                ProgressView()
                    .padding(20)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .safeAreaInset(edge: .bottom) { bottomCTA }
        .interactiveDismissDisabled(viewModel.isSaving)
        .modifier(RecordingNavigationChromeModifier(presentation: presentation, navigationTitle: recordingTitle))
    }

    private var bottomCTA: some View {
        Button {
            Task { await attemptSave() }
        } label: {
            HStack {
                Image(systemName: "tray.and.arrow.down.fill")
                Text(viewModel.isSaving ? "保存中..." : "保存する")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.pink)
        .disabled(viewModel.isSaving)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    @MainActor
    private func attemptSave() async {
        let ok = await viewModel.save()
        guard ok else { return }
        onSavedMoveToHistory()
        if presentation == .sheet {
            dismiss()
        }
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
        presentation: .sheet,
        onSavedMoveToHistory: {}
    )
    .environment(\.networkMonitor, NetworkMonitor(startsMonitoring: false))
}

// MARK: - Navigation chrome

private struct RecordingNavigationChromeModifier: ViewModifier {
    let presentation: RecordingContentPresentation
    let navigationTitle: String

    func body(content: Content) -> some View {
        if presentation == .navigationStack {
            content
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            content
        }
    }
}
