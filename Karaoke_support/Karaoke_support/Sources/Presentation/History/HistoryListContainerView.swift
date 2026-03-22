import SwiftUI

/// `@Environment` で渡る `sessionRepository` から **初回描画時点で** ``HistoryViewModel`` を生成する。
/// `HistoryRootView` で `onAppear` まで遅延すると `Color.clear` 1 フレームが出うるため分離する。
struct HistoryListContainerView: View {
	@State private var viewModel: HistoryViewModel

	init(sessionRepository: any SessionRepositoryProtocol) {
		_viewModel = State(initialValue: HistoryViewModel(sessionRepository: sessionRepository))
	}

	var body: some View {
		HistoryListView(viewModel: viewModel)
	}
}

#Preview {
	NavigationStack {
		HistoryListContainerView(sessionRepository: PreviewSessionRepository())
	}
}
