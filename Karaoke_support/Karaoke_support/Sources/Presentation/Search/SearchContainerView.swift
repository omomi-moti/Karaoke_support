import SwiftUI

struct SearchContainerView: View {
    let onSelectTrack: (SelectedTrack) -> Void

    @State private var viewModel: SearchViewModel

    init(
        trackRepository: any TrackRepositoryProtocol,
        onSelectTrack: @escaping (SelectedTrack) -> Void
    ) {
        self.onSelectTrack = onSelectTrack
        _viewModel = State(
            initialValue: SearchViewModel(trackRepository: trackRepository)
        )
    }

    var body: some View {
        SearchView(
            viewModel: viewModel,
            onSelectTrack: { track in
                guard let selected = SelectedTrack(
                    spotifyTrackId: track.spotifyTrackId,
                    userEnteredName: track.userEnteredName
                ) else {
                    assertionFailure("Track must have spotifyTrackId or userEnteredName.")
                    return
                }
                onSelectTrack(selected)
            }
        )
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackgroundGradient()
        .navigationTitle("検索")
        .searchable(text: $viewModel.searchText, prompt: "過去に歌った曲から検索")
    }
}

#Preview {
    NavigationStack {
        SearchContainerView(
            trackRepository: PreviewTrackRepository(),
            onSelectTrack: { _ in }
        )
    }
}
