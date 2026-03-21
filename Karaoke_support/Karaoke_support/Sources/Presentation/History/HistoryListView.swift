import SwiftUI

/// 履歴タブの本体（一覧 + フィルター）。`HistoryViewModel` を `@Bindable` で受け取る。
struct HistoryListView: View {
	@Bindable var viewModel: HistoryViewModel

	var body: some View {
		ZStack {
			LinearGradient(
				colors: [
					Color(red: 0.06, green: 0.06, blue: 0.09),
					Color.black,
				],
				startPoint: .top,
				endPoint: .bottom
			)
			.ignoresSafeArea()

			VStack(alignment: .leading, spacing: 12) {
				HistoryFilterBarView(selection: $viewModel.filter)
					.padding(.top, 4)

				if let message = viewModel.loadErrorMessage {
					Text(message)
						.font(.footnote)
						.foregroundStyle(.red)
						.padding(.horizontal, 4)
				}

				if viewModel.isLoading && viewModel.sessions.isEmpty {
					ProgressView()
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				} else if viewModel.sessions.isEmpty {
					emptyState
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				} else {
					ScrollView {
						LazyVStack(spacing: 12) {
							ForEach(viewModel.sessions, id: \.id) { session in
								HistorySessionRowView(session: session)
							}
						}
						.padding(.vertical, 8)
					}
				}
			}
			.padding(.horizontal, 16)
		}
		.navigationTitle("履歴")
		.navigationBarTitleDisplayMode(.inline)
		.task {
			await viewModel.load()
		}
		.onChange(of: viewModel.filter) { _, _ in
			Task { await viewModel.load() }
		}
	}

	private var emptyState: some View {
		VStack(spacing: 12) {
			Image(systemName: "clock.arrow.circlepath")
				.font(.system(size: 44))
				.foregroundStyle(.secondary)
			Text("まだ記録がありません")
				.font(.title3.weight(.semibold))
				.foregroundStyle(.primary)
			Text("選曲タブから歌った記録がここに並びます。")
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
		}
		.padding(32)
	}
}

#Preview {
	NavigationStack {
		HistoryListView(viewModel: HistoryViewModel(sessionRepository: PreviewSessionRepository()))
	}
}
