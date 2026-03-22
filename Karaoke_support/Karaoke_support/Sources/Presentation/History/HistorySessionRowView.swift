import SwiftUI

/// 履歴1件のカード行（I-014）。ダークカード・右寄せスコア。
struct HistorySessionRowView: View {
	let item: HistorySessionRowDisplayItem

	private static let performedAtFormatter: DateFormatter = {
		let f = DateFormatter()
		f.locale = Locale(identifier: "ja_JP")
		f.dateStyle = .medium
		f.timeStyle = .short
		return f
	}()

	var body: some View {
		HStack(alignment: .top, spacing: 12) {
			VStack(alignment: .leading, spacing: 6) {
				Text(item.trackPrimaryTitle)
					.font(.headline.weight(.semibold))
					.foregroundStyle(AppColor.textPrimary)
					.multilineTextAlignment(.leading)

				Text(Self.performedAtFormatter.string(from: item.performedAt))
					.font(.subheadline)
					.foregroundStyle(AppColor.textSecondary)

				HistoryIntentBadgeView(intent: item.intent)
			}
			.frame(maxWidth: .infinity, alignment: .leading)

			VStack(alignment: .trailing, spacing: 2) {
				Text(item.score, format: .number.precision(.fractionLength(1)))
					.font(.system(size: 30, weight: .bold, design: .rounded))
					.monospacedDigit()
					.foregroundStyle(AppColor.accentScore)
					.minimumScaleFactor(0.7)
					.lineLimit(1)

				Text("SCORE")
					.font(.caption2.weight(.semibold))
					.foregroundStyle(AppColor.textTertiary)
					.textCase(.uppercase)
			}
			.accessibilityElement(children: .combine)
			.accessibilityLabel("スコア \(item.score.formatted(.number.precision(.fractionLength(1))))")
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

#Preview("Row") {
	HistorySessionRowView(
		item: HistorySessionRowDisplayItem(
			id: UUID(),
			intent: .shout,
			trackPrimaryTitle: "アイドル",
			performedAt: .now,
			score: 92.5
		)
	)
	.padding()
	.background(AppColor.backgroundGradientEnd)
}
