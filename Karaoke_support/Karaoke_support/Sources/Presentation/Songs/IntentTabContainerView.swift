import SwiftUI

/// ``IntentTabViewModel`` を生成し、インテントタブを表示する（I-017）。
struct IntentTabContainerView: View {
	let onSelectTrack: (SelectedTrack) -> Void
	let onNavigateToManualRecording: () -> Void

	@State private var viewModel: IntentTabViewModel

	init(
		insightRepository: any InsightRepositoryProtocol,
		sessionRepository: any SessionRepositoryProtocol,
		onSelectTrack: @escaping (SelectedTrack) -> Void,
		onNavigateToManualRecording: @escaping () -> Void
	) {
		self.onSelectTrack = onSelectTrack
		self.onNavigateToManualRecording = onNavigateToManualRecording
		_viewModel = State(
			initialValue: IntentTabViewModel(
				insightRepository: insightRepository,
				sessionRepository: sessionRepository
			)
		)
	}

	var body: some View {
		IntentTabInsightView(
			viewModel: viewModel,
			onSelectTrack: onSelectTrack,
			onNavigateToManualRecording: onNavigateToManualRecording
		)
		.onAppear {
			Task { await viewModel.load() }
		}
	}
}

#Preview {
	IntentTabContainerView(
		insightRepository: PreviewInsightRepository(),
		sessionRepository: PreviewSessionRepository(),
		onSelectTrack: { _ in },
		onNavigateToManualRecording: {}
	)
}
