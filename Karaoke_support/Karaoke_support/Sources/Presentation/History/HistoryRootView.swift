import SwiftUI

struct HistoryRootView: View {
	@Environment(\.sessionRepository) private var sessionRepository

	var body: some View {
		HistoryListContainerView(sessionRepository: sessionRepository)
	}
}

#Preview {
	HistoryRootView()
		.environment(\.sessionRepository, PreviewSessionRepository())
}
