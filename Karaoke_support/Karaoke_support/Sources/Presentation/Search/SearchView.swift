import SwiftUI
import Observation

struct SearchView: View {
    @Bindable var viewModel: SearchViewModel
    let onSelectTrack: (Track) -> Void

    var body: some View {
        Group {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.semanticError)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.result.isEmpty && viewModel.hasActiveQuery {
                Text("該当する曲が見つかりません")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.result) { track in
                    Button {
                        onSelectTrack(track)
                    } label: {
                        SearchResultRowView(track: track)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .task(id: viewModel.searchText) {
            await viewModel.search(query: viewModel.searchText)
        }
    }
}
