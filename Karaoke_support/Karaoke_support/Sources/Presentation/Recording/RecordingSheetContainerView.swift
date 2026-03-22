import SwiftUI

struct RecordingSheetContainerView: View {
	@Environment(\.sessionRepository) private var sessionRepository
	@Environment(\.trackRepository) private var trackRepository
	@Environment(\.dismiss) private var dismiss

	let seed: RecordingSessionSeed
	let presentation: RecordingContentPresentation
	let onSavedMoveToHistory: () -> Void

	/// 親の `body` が再評価されるたびに `RecordingSheetViewModel` を作り直さない（I-011 `pendingSessionIdForSave` の整合）。
	@State private var viewModel: RecordingSheetViewModel?
	@State private var loadErrorMessage: String?

	init(
		seed: RecordingSessionSeed,
		presentation: RecordingContentPresentation = .sheet,
		onSavedMoveToHistory: @escaping () -> Void
	) {
		self.seed = seed
		self.presentation = presentation
		self.onSavedMoveToHistory = onSavedMoveToHistory
	}

	/// 従来どおり ``TrackInputMode`` から開始。
	init(
		trackMode: TrackInputMode,
		presentation: RecordingContentPresentation = .sheet,
		onSavedMoveToHistory: @escaping () -> Void
	) {
		self.init(seed: .mode(trackMode), presentation: presentation, onSavedMoveToHistory: onSavedMoveToHistory)
	}

	var body: some View {
		Group {
			if let msg = loadErrorMessage {
				VStack(spacing: 16) {
					Text(msg)
						.font(.body)
						.multilineTextAlignment(.center)
						.foregroundStyle(.secondary)
					Button("閉じる") {
						dismiss()
					}
					.buttonStyle(.borderedProminent)
				}
				.padding(24)
			} else if let vm = viewModel {
				RecordingSheetContentView(
					viewModel: vm,
					presentation: presentation,
					onSavedMoveToHistory: onSavedMoveToHistory
				)
			} else {
				Color.clear
					.frame(width: 0, height: 0)
					.accessibilityHidden(true)
			}
		}
		.task(id: seed) {
			await buildViewModelIfNeeded()
		}
	}

	@MainActor
	private func buildViewModelIfNeeded() async {
		guard viewModel == nil, loadErrorMessage == nil else { return }
		switch seed {
		case .mode(let mode):
			viewModel = RecordingSheetViewModel(
				trackMode: mode,
				sessionRepository: sessionRepository,
				trackRepository: trackRepository
			)
		case .selectedTrack(let track):
			viewModel = RecordingSheetViewModel(
				selectedTrack: track,
				sessionRepository: sessionRepository,
				trackRepository: trackRepository
			)
		case .editSession(let sessionId):
			do {
				let session = try await sessionRepository.fetchRecordingSession(uuid: sessionId)
				viewModel = RecordingSheetViewModel(
					editingSession: session,
					sessionRepository: sessionRepository,
					trackRepository: trackRepository
				)
			} catch {
				loadErrorMessage = "記録を読み込めませんでした。もう一度お試しください"
			}
		}
	}
}

#Preview {
	RecordingSheetContainerView(trackMode: .manual, onSavedMoveToHistory: {})
		.environment(\.networkMonitor, NetworkMonitor(startsMonitoring: false))
		.environment(\.trackRepository, PreviewTrackRepository())
}
