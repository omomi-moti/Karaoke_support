import SwiftUI

/// `@Environment` で渡る `sessionRepository` から **初回描画時点で** ``HistoryViewModel`` を生成する。
/// `HistoryRootView` で `onAppear` まで遅延すると `Color.clear` 1 フレームが出うるため分離する。
///
/// 履歴→編集は ``NavigationStack`` + `navigationDestination(for: UUID.self)`（I-014-C）。
struct HistoryListContainerView: View {
	@State private var viewModel: HistoryViewModel
	@State private var editPath = NavigationPath()

	init(sessionRepository: any SessionRepositoryProtocol) {
		_viewModel = State(initialValue: HistoryViewModel(sessionRepository: sessionRepository))
	}

	var body: some View {
		NavigationStack(path: $editPath) {
			HistoryListView(viewModel: viewModel, editNavigationPath: $editPath)
				.navigationDestination(for: UUID.self) { sessionId in
					RecordingSheetContainerView(
						seed: .editSession(sessionId: sessionId),
						presentation: .navigationStack,
						onSavedMoveToHistory: {
							editPath.removeLast()
							Task { await viewModel.load() }
						}
					)
				}
		}
	}
}

#Preview {
	HistoryListContainerView(sessionRepository: PreviewSessionRepository())
}
