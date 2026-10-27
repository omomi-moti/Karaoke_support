import SwiftUI

struct SongsRootView: View {
    let onSelectTrack: (SelectedTrack) -> Void

    @Environment(\.navigateToManualRecording) private var navigateToManualRecording

    var body: some View {
        NavigationStack {
            SingingEmptyStateView(onManualEntryTap: navigateToManualRecording)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .appBackgroundGradient()
                .navigationTitle("選曲")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SongsRootView(onSelectTrack: { _ in })
        .environment(\.navigateToManualRecording) {}
}
