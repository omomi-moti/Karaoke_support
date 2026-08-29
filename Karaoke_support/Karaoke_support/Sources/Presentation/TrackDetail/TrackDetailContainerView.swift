import SwiftUI

/// `@Environment` から渡る Repository で、初回描画時点から ``TrackDetailViewModel`` を生成する。
struct TrackDetailContainerView: View {
	@State private var viewModel: TrackDetailViewModel

	init(
		sessionRepository: any SessionRepositoryProtocol,
		trackId: UUID,
		trackTitle: String
	) {
		_viewModel = State(
			initialValue: TrackDetailViewModel(
				sessionRepository: sessionRepository,
				trackId: trackId,
				trackTitle: trackTitle
			)
		)
	}

	var body: some View {
		TrackDetailView(viewModel: viewModel)
	}
}

#Preview {
	NavigationStack {
		TrackDetailContainerView(
			sessionRepository: PreviewSessionRepository(),
			trackId: PreviewSessionRepository.sampleTrackIdForTrend,
			trackTitle: "アイドル"
		)
	}
}
