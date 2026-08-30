import SwiftUI

/// 曲ごとの点数推移画面（I-019）。読み取り専用。編集は履歴のリードスワイプに一本化する。
struct TrackDetailView: View {
	let viewModel: TrackDetailViewModel

	var body: some View {
		ZStack {
			AppBackgroundGradientView()
			content
		}
		.navigationBarTitleDisplayMode(.inline)
		.task {
			await viewModel.load()
		}
	}

	@ViewBuilder
	private var content: some View {
		if viewModel.isLoading && viewModel.points.isEmpty {
			ProgressView()
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		} else {
			ScrollView {
				VStack(alignment: .leading, spacing: 20) {
					heroHeader

					if let message = viewModel.loadErrorMessage {
						InlineErrorRetryView(message: message, retryTitle: "再試行") {
							Task { await viewModel.load() }
						}
						.disabled(viewModel.isLoading)
					} else if let summary = viewModel.summary {
						latestScoreBlock(summary)
						TrackScoreTrendChartView(
							points: viewModel.chartPoints,
							averageScore: summary.averageScore,
							isTruncated: viewModel.isChartTruncated
						)
						sessionList
					} else {
						emptyState
					}
				}
				.padding(.horizontal, 16)
				.padding(.bottom, 28)
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
				Text(summary.latestScore, format: .number.precision(.fractionLength(1)))
					.font(.system(size: 44, weight: .bold, design: .rounded))
					.monospacedDigit()
					.foregroundStyle(AppColor.textPrimary)

				if let delta = summary.deltaFromPrevious {
					Text("前回比 \(delta, format: .number.precision(.fractionLength(1)).sign(strategy: .always()))")
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
		let average = summary.averageScore.formatted(.number.precision(.fractionLength(1)))
		let best = summary.bestScore.formatted(.number.precision(.fractionLength(1)))
		return "\(summary.count)回 ・ 平均 \(average) ・ ベスト \(best)"
	}

	/// グラフは古い→新しい、リストは履歴タブと同じ新しい順。
	private var sessionList: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("履歴")
				.font(.headline)
				.foregroundStyle(AppColor.textPrimary)
			ForEach(viewModel.points.reversed()) { point in
				TrackDetailSessionRowView(point: point)
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
