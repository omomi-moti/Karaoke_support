import SwiftUI

struct SettingsRootView: View {
	@Environment(\.insightRepository) private var insightRepository

	var body: some View {
		SettingsContainerView(insightRepository: insightRepository)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.appBackgroundGradient()
			.navigationTitle("設定")
			.navigationBarTitleDisplayMode(.inline)
	}
}

#Preview {
	NavigationStack {
		SettingsRootView()
	}
	.environment(\.insightRepository, PreviewInsightRepository())
}
