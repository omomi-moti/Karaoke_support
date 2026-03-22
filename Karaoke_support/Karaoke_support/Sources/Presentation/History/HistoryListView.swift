import SwiftUI

/// 履歴タブの本体（一覧 + フィルター）。`HistoryViewModel` を `@Bindable` で受け取る。
struct HistoryListView: View {
	@Bindable var viewModel: HistoryViewModel

	var body: some View {
		ZStack {
			LinearGradient(
				colors: [
					AppColor.backgroundGradientStart,
					AppColor.backgroundGradientEnd,
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
						.foregroundStyle(AppColor.semanticError)
						.padding(.horizontal, 4)
				}

				if let deleteMsg = viewModel.deleteErrorMessage {
					Text(deleteMsg)
						.font(.footnote)
						.foregroundStyle(AppColor.semanticError)
						.padding(.horizontal, 4)
				}

				if viewModel.isLoading && viewModel.sessions.isEmpty {
					ProgressView()
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				} else if viewModel.sessions.isEmpty {
					emptyState
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				} else {
					List {
						ForEach(viewModel.sessions, id: \.id) { session in
							HistorySessionRowView(item: session)
								.listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
								.listRowSeparator(.hidden)
								.listRowBackground(Color.clear)
								.swipeActions(edge: .trailing, allowsFullSwipe: true) {
									Button(role: .destructive) {
										let idToDelete = session.id
										Task { await viewModel.deleteSession(id: idToDelete) }
									} label: {
										Label("削除", systemImage: "trash")
									}
								}
						}
					}
					// 削除で SwiftData インスタンスが無効化される前に、List のデフォルト削除アニメが古い行を触るのを抑える
					.animation(nil, value: viewModel.sessions.map(\.id))
					.listStyle(.plain)
					.scrollContentBackground(.hidden)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
				}
			}
			.padding(.horizontal, 16)
		}
		.navigationTitle("履歴")
		.navigationBarTitleDisplayMode(.inline)
		/// `filter` 変更時に前の非同期タスクをキャンセルし、最新の絞り込みだけ `load()` させる（連打時のレース回避）。
		.task(id: viewModel.filter) {
			await viewModel.load()
		}
	}

	private var emptyState: some View {
		VStack(spacing: 12) {
			Image(systemName: "clock.arrow.circlepath")
				.font(.system(size: 44))
				.foregroundStyle(AppColor.textSecondary)
			switch viewModel.filter {
			case .all:
				Text("まだ記録がありません")
					.font(.title3.weight(.semibold))
					.foregroundStyle(AppColor.textPrimary)
				Text("選曲タブから歌った記録がここに並びます。")
					.font(.subheadline)
					.foregroundStyle(AppColor.textSecondary)
					.multilineTextAlignment(.center)
			case .intent:
				Text("直近の記録に該当がありません")
					.font(.title3.weight(.semibold))
					.foregroundStyle(AppColor.textPrimary)
					.multilineTextAlignment(.center)
				Text("フィルターを変えるか、該当するインテントで記録を追加してください。")
					.font(.subheadline)
					.foregroundStyle(AppColor.textSecondary)
					.multilineTextAlignment(.center)
			}
		}
		.padding(32)
	}
}

#Preview {
	NavigationStack {
		HistoryListView(viewModel: HistoryViewModel(sessionRepository: PreviewSessionRepository()))
	}
}
