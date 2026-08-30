import SwiftUI

/// `@Environment` で渡る `sessionRepository` から **初回描画時点で** ``HistoryViewModel`` を生成する。
/// `HistoryRootView` で `onAppear` まで遅延すると `Color.clear` 1 フレームが出うるため分離する。
///
/// 履歴→曲詳細（行タップ・I-019）と履歴→編集（リードスワイプ・I-014-C）を ``HistoryRoute`` で振り分ける。
struct HistoryListContainerView: View {
	private let sessionRepository: any SessionRepositoryProtocol
	@State private var viewModel: HistoryViewModel
	@State private var navigationPath = NavigationPath()

	init(sessionRepository: any SessionRepositoryProtocol) {
		self.sessionRepository = sessionRepository
		_viewModel = State(initialValue: HistoryViewModel(sessionRepository: sessionRepository))
	}

	var body: some View {
		NavigationStack(path: $navigationPath) {
			HistoryListView(viewModel: viewModel, navigationPath: $navigationPath)
				.navigationDestination(for: HistoryRoute.self) { route in
					switch route {
					case .trackDetail(let trackId, let title):
						TrackDetailContainerView(
							sessionRepository: sessionRepository,
							trackId: trackId,
							trackTitle: title
						)
					case .editSession(let sessionId):
						RecordingSheetContainerView(
							seed: .editSession(sessionId: sessionId),
							presentation: .navigationStack,
							onSavedMoveToHistory: {
								if !navigationPath.isEmpty {
									navigationPath.removeLast()
								}
								Task { await viewModel.load() }
							}
						)
					}
				}
		}
	}
}

#Preview {
	HistoryListContainerView(sessionRepository: PreviewSessionRepository())
		.environment(\.navigateToManualRecording) {}
}
