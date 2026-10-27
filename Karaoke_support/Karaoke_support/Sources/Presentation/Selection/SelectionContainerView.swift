import SwiftUI

/// ``SelectionViewModel`` を作り、選曲画面を出す（#126）。記録を保存するたびに読み直す。
struct SelectionContainerView: View {
	let onSelect: (TrackRecommendation, Intent) -> Void
	let onNavigateToManualRecording: () -> Void

	@Environment(\.historyReloadTick) private var historyReloadTick
	@State private var viewModel: SelectionViewModel

	init(
		trackStatsRepository: any TrackStatsRepositoryProtocol,
		onSelect: @escaping (TrackRecommendation, Intent) -> Void,
		onNavigateToManualRecording: @escaping () -> Void
	) {
		self.onSelect = onSelect
		self.onNavigateToManualRecording = onNavigateToManualRecording
		_viewModel = State(initialValue: SelectionViewModel(trackStatsRepository: trackStatsRepository))
	}

	var body: some View {
		SelectionView(
			viewModel: viewModel,
			onSelect: onSelect,
			onNavigateToManualRecording: onNavigateToManualRecording
		)
		.task(id: historyReloadTick) {
			await viewModel.load()
		}
	}
}

#Preview {
	SelectionContainerView(
		trackStatsRepository: PreviewTrackStatsRepository(),
		onSelect: { _, _ in },
		onNavigateToManualRecording: {}
	)
	.appBackgroundGradient()
}
