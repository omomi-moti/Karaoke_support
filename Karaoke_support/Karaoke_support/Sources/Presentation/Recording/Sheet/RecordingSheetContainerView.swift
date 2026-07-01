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
	/// ``RecordingSessionSeed/editSession(sessionId:)`` のフェッチ試行ごとに増加。完了時は `await` 後もこの値と一致するときだけ状態を書く（再試行連打のレース回避）。
	@State private var editSessionFetchGeneration: UInt = 0

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
					Button("再試行") {
						loadErrorMessage = nil
						Task {
							await buildViewModelIfNeeded()
						}
					}
					.buttonStyle(.borderedProminent)
					.accessibilityHint("記録を読み込み直します")
					Button("閉じる") {
						dismiss()
					}
					.buttonStyle(.bordered)
					.accessibilityLabel("閉じる")
				}
				.padding(24)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.background(
					LinearGradient(
						colors: [
							AppColor.backgroundGradientStart,
							AppColor.backgroundGradientEnd,
						],
						startPoint: .top,
						endPoint: .bottom
					)
					.ignoresSafeArea()
				)
			} else if let vm = viewModel {
				RecordingSheetContentView(
					viewModel: vm,
					presentation: presentation,
					onSavedMoveToHistory: onSavedMoveToHistory
				)
			} else {
				LinearGradient(
					colors: [
						AppColor.backgroundGradientStart,
						AppColor.backgroundGradientEnd,
					],
					startPoint: .top,
					endPoint: .bottom
				)
				.ignoresSafeArea()
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
			editSessionFetchGeneration += 1
			let attempt = editSessionFetchGeneration
			do {
				let session = try await sessionRepository.fetchRecordingSession(uuid: sessionId)
				guard attempt == editSessionFetchGeneration else { return }
				viewModel = RecordingSheetViewModel(
					editingSession: session,
					sessionRepository: sessionRepository,
					trackRepository: trackRepository
				)
			} catch {
				guard attempt == editSessionFetchGeneration else { return }
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
