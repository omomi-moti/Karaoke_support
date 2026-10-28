import SwiftUI

/// 曲ごとの点数推移画面（I-019）。記録の行は履歴と同じく、右へスワイプで編集、左へスワイプで削除（#135）。
struct TrackDetailView: View {
	let viewModel: TrackDetailViewModel

	@Environment(\.dismiss) private var dismiss
	@Environment(\.historyReloadTick) private var historyReloadTick
	@Environment(\.navigateToEditRecording) private var navigateToEditRecording
	@Environment(\.notifyRecordsChanged) private var notifyRecordsChanged
	/// 削除の確認を出している記録。
	@State private var pendingDeleteSessionId: UUID?

	var body: some View {
		ZStack {
			AppBackgroundGradientView()
			content
		}
		.navigationBarTitleDisplayMode(.inline)
		.task(id: historyReloadTick) {
			await viewModel.load()
		}
	}

	@ViewBuilder
	private var content: some View {
		if viewModel.isLoading && viewModel.points.isEmpty {
			ProgressView()
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		} else {
			List {
				Group {
					heroHeader

					if let message = viewModel.loadErrorMessage {
						InlineErrorRetryView(message: message, retryTitle: "再試行") {
							Task { await viewModel.load() }
						}
						.disabled(viewModel.isLoading)
					} else if let summary = viewModel.summary {
						latestScoreBlock(summary)
						// 点数ありの記録が 1 件も無ければグラフは出さない
						if let averageScore = summary.averageScore {
							TrackScoreTrendChartView(
								points: viewModel.chartPoints,
								averageScore: averageScore,
								isTruncated: viewModel.isChartTruncated
							)
						}
						sessionList
					} else {
						emptyState
					}
				}
				.listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
				.listRowSeparator(.hidden)
				.listRowBackground(Color.clear)
			}
			.listStyle(.plain)
			.scrollContentBackground(.hidden)
			.addRecordingButtonClearance()
			.recordDeleteConfirmation(pendingSessionId: $pendingDeleteSessionId) { idToDelete in
				Task {
					await viewModel.deleteSession(id: idToDelete)
					notifyRecordsChanged()
					if viewModel.points.isEmpty {
						dismiss()
					}
				}
			}
		}
	}

	private var heroHeader: some View {
		VStack(alignment: .leading, spacing: 12) {
			Image(systemName: "music.note")
				.font(.title2)
				.foregroundStyle(AppColor.textSecondary)
				.frame(width: 48, height: 48)
				.background(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(AppColor.surfaceCard)
				)

			VStack(alignment: .leading, spacing: 4) {
				Text("この曲の記録")
					.font(.caption.weight(.semibold))
					.foregroundStyle(AppColor.textSecondary)
				Text(viewModel.trackTitle)
					.font(.system(size: 24, weight: .bold))
					.foregroundStyle(AppColor.textPrimary)
					.lineLimit(1)
					.truncationMode(.tail)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.top, 8)
	}

	/// 主役は「直近スコアと前回差」1つだけ。回数・平均・最高は補足の 1 行に降格する。
	private func latestScoreBlock(_ summary: TrackScoreSummary) -> some View {
		VStack(alignment: .leading, spacing: 6) {
			Text("直近スコア")
				.font(.caption.weight(.semibold))
				.foregroundStyle(AppColor.textSecondary)

			HStack(alignment: .firstTextBaseline, spacing: 12) {
				Text(ScoreFormat.text(summary.latestScore))
					.font(.system(size: 44, weight: .bold, design: .rounded))
					.monospacedDigit()
					.foregroundStyle(summary.latestScore == nil ? AppColor.textTertiary : AppColor.textPrimary)

				if summary.latestScore == nil {
					Text("点数の記録はまだありません")
						.font(.subheadline)
						.foregroundStyle(AppColor.textSecondary)
				} else if let delta = summary.deltaFromPrevious {
					Text("前回比 \(ScoreFormat.signedText(delta))")
						.font(.subheadline.weight(.semibold))
						.monospacedDigit()
						.foregroundStyle(AppColor.textSecondary)
				} else {
					Text("はじめての記録")
						.font(.subheadline)
						.foregroundStyle(AppColor.textSecondary)
				}
			}

			Text(supplementaryStatsText(summary))
				.font(.footnote)
				.foregroundStyle(AppColor.textTertiary)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private func supplementaryStatsText(_ summary: TrackScoreSummary) -> String {
		let average = ScoreFormat.averageText(summary.averageScore)
		let best = ScoreFormat.text(summary.bestScore)
		return "\(summary.count)回 ・ 平均 \(average) ・ ベスト \(best)"
	}

	/// グラフは古い→新しい、リストは履歴タブと同じ新しい順。
	@ViewBuilder
	private var sessionList: some View {
		Text("履歴")
			.font(.headline)
			.foregroundStyle(AppColor.textPrimary)
		if let message = viewModel.deleteErrorMessage {
			Text(message)
				.font(.subheadline)
				.foregroundStyle(AppColor.semanticError)
		}
		ForEach(viewModel.points.reversed()) { point in
			TrackDetailSessionRowView(point: point)
				.listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
				.swipeActions(edge: .leading, allowsFullSwipe: true) {
					Button {
						navigateToEditRecording(point.id)
					} label: {
						Label("編集", systemImage: "pencil")
					}
					.tint(AppColor.editAccent)
				}
				.swipeActions(edge: .trailing, allowsFullSwipe: true) {
					Button {
						pendingDeleteSessionId = point.id
					} label: {
						Label("削除", systemImage: "trash")
					}
					.tint(.red)
				}
		}
	}

	private var emptyState: some View {
		VStack(spacing: 12) {
			Image(systemName: "chart.line.uptrend.xyaxis")
				.font(.system(size: 44))
				.foregroundStyle(AppColor.textSecondary)
			Text("この曲の記録がありません")
				.font(.title3.weight(.semibold))
				.foregroundStyle(AppColor.textPrimary)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 48)
	}
}

#Preview {
	NavigationStack {
		TrackDetailContainerView(
			sessionRepository: PreviewSessionRepository(),
			trackId: PreviewSessionRepository.sampleTrackIdForTrend,
			trackTitle: "アイドル"
		)
	}
}
