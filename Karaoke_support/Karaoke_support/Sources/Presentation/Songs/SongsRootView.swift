import SwiftUI

struct SongsRootView: View {
    let onSelectTrack: (SelectedTrack) -> Void

    @Environment(\.insightRepository) private var insightRepository
    @Environment(\.sessionRepository) private var sessionRepository
    @Environment(\.navigateToManualRecording) private var navigateToManualRecording

    var body: some View {
        NavigationStack {
            IntentTabContainerView(
                insightRepository: insightRepository,
                sessionRepository: sessionRepository,
                onSelectTrack: onSelectTrack,
                onNavigateToManualRecording: navigateToManualRecording
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appBackgroundGradient()
            .navigationTitle("選曲")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SongsRootView(onSelectTrack: { _ in })
        .environment(\.insightRepository, PreviewInsightRepository())
        .environment(\.sessionRepository, PreviewSessionRepository())
        .environment(\.navigateToManualRecording) {}
}
