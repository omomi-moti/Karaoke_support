import SwiftUI
import Observation

struct SearchView: View {
    @Bindable var viewModel: SearchViewModel
    let onSelectTrack: (SearchResultDisplayItem) -> Void

    var body: some View {
        Group {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.semanticError)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.hasActiveQuery {
                recent
            } else if !viewModel.result.isEmpty {
                List {
                    Section("検索結果") {
                        ForEach(viewModel.result) { item in
                            SearchResultRowView(item: item, onTap: { onSelectTrack(item) })
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.immediately)
            } else if viewModel.isSearching {
                Color.clear
            } else {
                Text("該当する曲が見つかりません")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: viewModel.searchText) {
            await viewModel.search(query: viewModel.searchText)
        }
    }

    /// 何も打っていない間の画面（#142）。検索欄が有効な間に出す検索の候補（`searchSuggestions`）と同じ見た目にする。
    @ViewBuilder
    private var recent: some View {
        if let message = viewModel.recentErrorMessage {
            VStack(spacing: 12) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.semanticError)
                Button("再試行") {
                    Task { await viewModel.loadRecent() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink.opacity(0.85))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                if !viewModel.recentTracks.isEmpty {
                    Section("最近歌った曲") {
                        ForEach(viewModel.recentTracks) { item in
                            SearchResultRowView(item: item, onTap: { onSelectTrack(item) })
                                .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}
