import SwiftUI

/// 曲詳細の履歴行。曲名は画面ヘッダーにあるため、日時・Intent・スコアのみ。
struct TrackDetailSessionRowView: View {
	let point: TrackScoreTrendPoint

	private static let performedAtFormatter: DateFormatter = {
		let f = DateFormatter()
		f.locale = Locale(identifier: "ja_JP")
		f.dateStyle = .medium
		f.timeStyle = .short
		return f
	}()

	var body: some View {
		HStack(alignment: .center, spacing: 12) {
			VStack(alignment: .leading, spacing: 8) {
				Text(Self.performedAtFormatter.string(from: point.performedAt))
					.font(.subheadline)
					.foregroundStyle(AppColor.textSecondary)
				IntentBadgeView(intent: point.intent)
			}
			.frame(maxWidth: .infinity, alignment: .leading)

			VStack(alignment: .trailing, spacing: 2) {
				Text(point.score, format: .number.precision(.fractionLength(1)))
					.font(.system(size: 26, weight: .bold, design: .rounded))
					.monospacedDigit()
					.foregroundStyle(AppColor.textPrimary)
					.minimumScaleFactor(0.7)
					.lineLimit(1)
				Text("SCORE")
					.font(.caption2.weight(.semibold))
					.foregroundStyle(AppColor.textTertiary)
			}
			.accessibilityElement(children: .combine)
			.accessibilityLabel("スコア \(point.score.formatted(.number.precision(.fractionLength(1))))")
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
}

#Preview {
	TrackDetailSessionRowView(
		point: TrackScoreTrendPoint(id: UUID(), order: 1, performedAt: .now, intent: .shout, score: 92.5)
	)
	.padding()
	.background(AppColor.backgroundGradientEnd)
}
