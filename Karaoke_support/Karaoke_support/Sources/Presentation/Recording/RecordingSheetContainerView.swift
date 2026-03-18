import SwiftUI

struct RecordingSheetContainerView: View {
	@Environment(\.sessionRepository) private var sessionRepository
	@Environment(\.trackRepository) private var trackRepository

	let trackMode: TrackInputMode
	let onSavedMoveToHistory: () -> Void

	var body: some View {
		RecordingSheetContentView(
			viewModel: RecordingSheetViewModel(
				trackMode: trackMode,
				sessionRepository: sessionRepository,
				trackRepository: trackRepository
			),
			onSavedMoveToHistory: onSavedMoveToHistory
		)
	}
}

#Preview {
	RecordingSheetContainerView(trackMode: .manual, onSavedMoveToHistory: {})
		.environment(\.networkMonitor, NetworkMonitor(startsMonitoring: false))
}

