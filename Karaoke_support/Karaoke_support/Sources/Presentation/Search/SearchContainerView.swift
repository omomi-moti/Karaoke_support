import SwiftUI

struct SearchContainerView: View {
    let onSelectTrack: (SelectedTrack) -> Void

    @Environment(\.historyReloadTick) private var historyReloadTick
    @State private var viewModel: SearchViewModel
    @FocusState private var isSearchFocused: Bool

    init(
        trackRepository: any TrackRepositoryProtocol,
        trackStatsRepository: any TrackStatsRepositoryProtocol,
        onSelectTrack: @escaping (SelectedTrack) -> Void
    ) {
        self.onSelectTrack = onSelectTrack
        _viewModel = State(
            initialValue: SearchViewModel(trackRepository: trackRepository, trackStatsRepository: trackStatsRepository)
        )
    }

    var body: some View {
        SearchView(viewModel: viewModel, onSelectTrack: select)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appBackgroundGradient()
            .navigationTitle("検索")
            .searchable(text: $viewModel.searchText, prompt: "曲名で探す")
            .searchFocused($isSearchFocused)
            .searchSuggestions {
                if !viewModel.hasActiveQuery && !viewModel.recentTracks.isEmpty {
                    Section("最近歌った曲") {
                        ForEach(viewModel.recentTracks) { item in
                            SearchResultRowView(item: item, onTap: { select(item) })
                        }
                    }
                }
            }
            .onAppear {
                isSearchFocused = true
            }
            .task(id: historyReloadTick) {
                await viewModel.loadRecent()
            }
    }

    private func select(_ item: SearchResultDisplayItem) {
        guard let selected = SelectedTrack(
            spotifyTrackId: item.spotifyTrackId,
            userEnteredName: item.userEnteredName
        ) else {
            assertionFailure("Track must have spotifyTrackId or userEnteredName.")
            return
        }
        onSelectTrack(selected)
    }
}

#Preview {
    NavigationStack {
        SearchContainerView(
            trackRepository: PreviewTrackRepository(),
            trackStatsRepository: PreviewTrackStatsRepository(),
            onSelectTrack: { _ in }
        )
    }
}
