import SwiftUI

/// 履歴タブの本体（一覧 + フィルター）。`HistoryViewModel` を `@Bindable` で受け取る。
struct HistoryListView: View {
	@Bindable var viewModel: HistoryViewModel
	@Binding var editNavigationPath: NavigationPath
	@Environment(\.navigateToManualRecording) private var navigateToManualRecording

	var body: some View {
		ZStack {
			AppBackgroundGradientView()

			VStack(alignment: .leading, spacing: 12) {
				HistoryFilterBarView(selection: $viewModel.filter)
					.padding(.top, 4)

				HistorySortControlView(sortOrder: $viewModel.sortOrder)
					.onChange(of: viewModel.sortOrder) { _, _ in
						viewModel.applySortToLoadedSessions()
					}

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
							NavigationLink(value: session.id) {
								HistorySessionRowView(item: session)
							}
							.task(id: session.id) {
								await viewModel.loadNextPageIfNeeded(currentItemID: session.id)
							}
							.buttonStyle(.plain)
							.listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
							.listRowSeparator(.hidden)
							.listRowBackground(Color.clear)
							.swipeActions(edge: .leading, allowsFullSwipe: true) {
								Button {
									editNavigationPath.append(session.id)
								} label: {
									Label("編集", systemImage: "pencil")
								}
								.tint(.blue)
							}
							.swipeActions(edge: .trailing, allowsFullSwipe: true) {
								Button(role: .destructive) {
									let idToDelete = session.id
									Task { await viewModel.deleteSession(id: idToDelete) }
								} label: {
									Label("削除", systemImage: "trash")
								}
							}
						}
						if viewModel.isLoadingNextPage {
							HStack {
								Spacer()
								ProgressView()
								Spacer()
							}
							.listRowSeparator(.hidden)
							.listRowBackground(Color.clear)
						}
					}
					// 削除で SwiftData インスタンスが無効化される前に、List のデフォルト削除アニメが古い行を触るのを抑える
					.animation(nil, value: viewModel.sessions.map(\.id))
					.listStyle(.plain)
					.scrollContentBackground(.hidden)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay{
                        if viewModel.isLoading {
                            ZStack {
                                AppColor.backgroundGradientEnd.opacity(0.4)
                                ProgressView()
                            }
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.animation(.easeInOut(duration: 0.15).delay(0.2)),
                                    removal: .opacity.animation(.easeInOut(duration: 0.1))
                                )
                            )
                        }
                    }
                    .allowsHitTesting(!viewModel.isLoading)
                    .animation(.easeInOut(duration: 0.001), value: viewModel.isLoading)
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
		Group {
			switch viewModel.filter {
			case .all:
				SingingEmptyStateView(onManualEntryTap: navigateToManualRecording)
			case .intent:
				VStack(spacing: 12) {
					Image(systemName: "clock.arrow.circlepath")
						.font(.system(size: 44))
						.foregroundStyle(AppColor.textSecondary)
					Text("直近の記録に該当がありません")
						.font(.title3.weight(.semibold))
						.foregroundStyle(AppColor.textPrimary)
						.multilineTextAlignment(.center)
					Text("フィルターを変えるか、該当するインテントで記録を追加してください。")
						.font(.subheadline)
						.foregroundStyle(AppColor.textSecondary)
						.multilineTextAlignment(.center)
				}
				.padding(32)
			}
		}
	}
}

#Preview {
	@Previewable @State var path = NavigationPath()
	return NavigationStack(path: $path) {
		HistoryListView(viewModel: HistoryViewModel(sessionRepository: PreviewSessionRepository()), editNavigationPath: $path)
			.navigationDestination(for: UUID.self) { _ in
				EmptyView()
			}
	}
	.environment(\.navigateToManualRecording) {}
}
