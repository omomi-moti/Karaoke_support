import Charts
import SwiftUI

/// 点数推移グラフ。線は単色1本、点だけ Intent 色で塗る。
struct TrackScoreTrendChartView: View {
	let points: [TrackScoreTrendPoint]
	let averageScore: Double
	let isTruncated: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			header
			chart
			legend
		}
		.padding(16)
		.background(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.fill(AppColor.surfaceCard)
		)
		.overlay(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.stroke(AppColor.borderSubtle, lineWidth: 1)
		)
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 2) {
			Text("点数推移")
				.font(.headline)
				.foregroundStyle(AppColor.textPrimary)
			if isTruncated {
				Text("直近\(TrackDetailViewModel.maxChartPoints)回")
					.font(.caption)
					.foregroundStyle(AppColor.textTertiary)
			}
		}
	}

	/// `foregroundStyle(by:)` を使うと Intent ごとに系列が分かれて線が割れるため、マークへ直接色を渡す。
	private var chart: some View {
		Chart(points) { point in
			LineMark(
				x: .value("歌唱回数", point.order),
				y: .value("スコア", point.score)
			)
			.foregroundStyle(AppColor.accentScore)
			.interpolationMethod(.catmullRom)

			PointMark(
				x: .value("歌唱回数", point.order),
				y: .value("スコア", point.score)
			)
			.foregroundStyle(IntentPalette.foreground(point.intent))
			.symbolSize(70)
			.accessibilityLabel(point.performedAt.formatted(date: .abbreviated, time: .omitted))
			.accessibilityValue("\(point.score.formatted(.number.precision(.fractionLength(1))))点")

			RuleMark(y: .value("平均", averageScore))
				.lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
				.foregroundStyle(AppColor.borderSubtle)
				.annotation(position: .top, alignment: .leading) {
					Text("平均 \(averageScore, format: .number.precision(.fractionLength(1)))")
						.font(.caption2.weight(.semibold))
						.foregroundStyle(AppColor.textTertiary)
				}
		}
		.chartYScale(domain: yDomain)
		.chartXScale(domain: xDomain)
		.chartLegend(.hidden)
		.chartYAxis {
			AxisMarks(values: .automatic(desiredCount: 4)) { _ in
				AxisGridLine().foregroundStyle(AppColor.borderSubtle)
				AxisValueLabel().foregroundStyle(AppColor.textTertiary)
			}
		}
		.chartXAxis {
			AxisMarks(values: .automatic(desiredCount: 5)) { _ in
				AxisValueLabel().foregroundStyle(AppColor.textTertiary)
			}
		}
		.frame(height: 200)
	}

	private var legend: some View {
		HStack(spacing: 8) {
			IntentBadgeView(intent: .shout)
			IntentBadgeView(intent: .emo)
			IntentBadgeView(intent: .practice)
		}
	}

	/// スコアの実レンジに 5 点刻みの余白を足した範囲。0〜100 固定だと変動が上端に潰れて推移が読めない。
	private var yDomain: ClosedRange<Double> {
		let scores = points.map(\.score) + [averageScore]
		guard let minScore = scores.min(), let maxScore = scores.max() else { return 0 ... 100 }
		let lower = max(0, (minScore / 5).rounded(.down) * 5 - 5)
		let upper = min(100, (maxScore / 5).rounded(.up) * 5 + 5)
		guard lower < upper else { return max(0, upper - 10) ... upper }
		return lower ... upper
	}

	private var xDomain: ClosedRange<Double> {
		let first = Double(points.first?.order ?? 1)
		let last = Double(points.last?.order ?? 1)
		return (first - 0.5) ... (last + 0.5)
	}
}

#Preview {
	TrackScoreTrendChartView(
		points: (1 ... 8).map { index in
			TrackScoreTrendPoint(
				id: UUID(),
				order: index,
				performedAt: .now.addingTimeInterval(Double(-86_400 * (9 - index))),
				intent: [Intent.shout, .emo, .practice][index % 3],
				score: Double(70 + index * 3)
			)
		},
		averageScore: 82.0,
		isTruncated: false
	)
	.padding()
	.background(AppColor.backgroundGradientEnd)
}
