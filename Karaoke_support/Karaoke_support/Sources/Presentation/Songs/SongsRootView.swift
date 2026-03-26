import SwiftUI

struct SongsRootView: View {
	let onSavedMoveToHistory: () -> Void
	@Binding var manualRecordingNavigationTick: Int

	@Environment(\.insightRepository) private var insightRepository
	@Environment(\.sessionRepository) private var sessionRepository
	@Environment(\.navigateToManualRecording) private var navigateToManualRecording

	/// 記録は `NavigationStack` の push ではなくシートで出し、保存後に pop でルートが一瞬見えるのを避ける。
	@State private var presentedRecordingRoute: SongsRecordingRoute?

	var body: some View {
		NavigationStack {
			IntentTabContainerView(
				insightRepository: insightRepository,
				sessionRepository: sessionRepository,
				onSelectTrack: { selected in
					presentedRecordingRoute = .recording(selected)
				},
				onNavigateToManualRecording: navigateToManualRecording
			)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.navigationTitle("選曲")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						presentedRecordingRoute = .manualRecording
					} label: {
						Label("記録を追加", systemImage: "plus")
					}
				}
			}
			.sheet(item: $presentedRecordingRoute) { route in
				RecordingSheetContainerView(
					seed: recordingSeed(for: route),
					presentation: .sheet,
					onSavedMoveToHistory: { handleRecordingSaved() }
				)
			}
			.onChange(of: manualRecordingNavigationTick) { _, newValue in
				guard newValue > 0 else { return }
				presentedRecordingRoute = .manualRecording
			}
		}
	}

	private func recordingSeed(for route: SongsRecordingRoute) -> RecordingSessionSeed {
		switch route {
		case .manualRecording:
			return .mode(.manual)
		case .recording(let selectedTrack):
			return .selectedTrack(selectedTrack)
		}
	}

	private func handleRecordingSaved() {
		onSavedMoveToHistory()
		presentedRecordingRoute = nil
	}
}

#Preview {
	SongsRootView(onSavedMoveToHistory: {}, manualRecordingNavigationTick: .constant(0))
		.environment(\.insightRepository, PreviewInsightRepository())
		.environment(\.sessionRepository, PreviewSessionRepository())
		.environment(\.navigateToManualRecording) {}
}
