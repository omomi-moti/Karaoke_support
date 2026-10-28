import SwiftUI

struct HistoryRootView: View {
	@Environment(\.sessionRepository) private var sessionRepository
	@Binding var navigationPath: [HistoryRoute]

	var body: some View {
		HistoryListContainerView(sessionRepository: sessionRepository, navigationPath: $navigationPath)
	}
}

#Preview {
	HistoryRootView(navigationPath: .constant([]))
		.environment(\.sessionRepository, PreviewSessionRepository())
		.environment(\.navigateToManualRecording) {}
}
