import SwiftUI

struct SongsRootView: View {
    let onSelect: (TrackRecommendation, Intent) -> Void

    @Environment(\.trackStatsRepository) private var trackStatsRepository
    @Environment(\.navigateToManualRecording) private var navigateToManualRecording

    var body: some View {
        NavigationStack {
            SelectionContainerView(
                trackStatsRepository: trackStatsRepository,
                onSelect: onSelect,
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
    SongsRootView(onSelect: { _, _ in })
        .environment(\.trackStatsRepository, PreviewTrackStatsRepository())
        .environment(\.navigateToManualRecording) {}
}
