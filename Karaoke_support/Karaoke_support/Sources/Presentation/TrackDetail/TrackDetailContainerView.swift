import SwiftUI

/// `@Environment` から渡る Repository で、初回描画時点から ``TrackDetailViewModel`` を生成する。
struct TrackDetailContainerView: View {
	@State private var viewModel: TrackDetailViewModel
	private let onTrackChanged: (UUID, String?) -> Void

	init(
		sessionRepository: any SessionRepositoryProtocol,
		trackRepository: any TrackRepositoryProtocol,
		trackId: UUID,
		trackTitle: String,
		trackArtistName: String? = nil,
		onTrackChanged: @escaping (UUID, String?) -> Void = { _, _ in }
	) {
		self.onTrackChanged = onTrackChanged
		_viewModel = State(
			initialValue: TrackDetailViewModel(
				sessionRepository: sessionRepository,
				trackRepository: trackRepository,
				trackId: trackId,
				trackTitle: trackTitle,
				trackArtistName: trackArtistName
			)
		)
	}

	var body: some View {
		TrackDetailView(viewModel: viewModel, onTrackChanged: onTrackChanged)
	}
}

#Preview {
	NavigationStack {
		TrackDetailContainerView(
			sessionRepository: PreviewSessionRepository(),
			trackRepository: PreviewTrackRepository(),
			trackId: PreviewSessionRepository.sampleTrackIdForTrend,
			trackTitle: "アイドル",
			trackArtistName: "YOASOBI"
		)
	}
}
