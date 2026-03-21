import SwiftUI

struct HistoryRootView: View {
	@Environment(\.sessionRepository) private var sessionRepository
	@State private var viewModel: HistoryViewModel?

	var body: some View {
		Group {
			if let vm = viewModel {
				HistoryListView(viewModel: vm)
			} else {
				Color.clear
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.onAppear {
						guard viewModel == nil else { return }
						viewModel = HistoryViewModel(sessionRepository: sessionRepository)
					}
			}
		}
	}
}

#Preview {
	NavigationStack {
		HistoryRootView()
			.environment(\.sessionRepository, PreviewSessionRepository())
	}
}
