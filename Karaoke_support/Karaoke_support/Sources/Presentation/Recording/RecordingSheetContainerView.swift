import SwiftUI

struct RecordingSheetContainerView: View {
	@Environment(\.sessionRepository) private var sessionRepository
	@Environment(\.trackRepository) private var trackRepository

	let trackMode: TrackInputMode
	let onSavedMoveToHistory: () -> Void

	/// 親の `body` が再評価されるたびに `RecordingSheetViewModel` を作り直さない（I-011 `pendingSessionIdForSave` の整合）。
	@State private var viewModel: RecordingSheetViewModel?

	var body: some View {
		Group {
			if let vm = viewModel {
				RecordingSheetContentView(
					viewModel: vm,
					onSavedMoveToHistory: onSavedMoveToHistory
				)
			} else {
				Color.clear
					.frame(width: 0, height: 0)
					.accessibilityHidden(true)
					.onAppear {
						guard viewModel == nil else { return }
						viewModel = RecordingSheetViewModel(
							trackMode: trackMode,
							sessionRepository: sessionRepository,
							trackRepository: trackRepository
						)
					}
			}
		}
	}
}

#Preview {
	RecordingSheetContainerView(trackMode: .manual, onSavedMoveToHistory: {})
		.environment(\.networkMonitor, NetworkMonitor(startsMonitoring: false))
}

