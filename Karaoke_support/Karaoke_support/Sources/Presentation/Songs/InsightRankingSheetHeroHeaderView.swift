import SwiftUI

/// ランキングシート上部の STATS 風ヒーローカード（I-017 / I-018 デザイン）。
struct InsightRankingSheetHeroHeaderView: View {
	let statsLabel: String
	let title: String
	let subtitle: String
	let systemImageName: String

	var body: some View {
		HStack(alignment: .center, spacing: 16) {
			VStack(alignment: .leading, spacing: 8) {
				Text(statsLabel)
					.font(.caption.weight(.semibold))
					.foregroundStyle(AppColor.accentScore)
					.tracking(3)
				Text(title)
					.font(.title2.weight(.bold))
					.foregroundStyle(AppColor.textPrimary)
					.fixedSize(horizontal: false, vertical: true)
				Text(subtitle)
					.font(.subheadline)
					.foregroundStyle(AppColor.textSecondary)
					.fixedSize(horizontal: false, vertical: true)
			}
			Spacer(minLength: 0)
			Image(systemName: systemImageName)
				.font(.system(size: 44, weight: .light))
				.foregroundStyle(
					LinearGradient(
						colors: [.white.opacity(0.55), .white.opacity(0.2)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)
				.accessibilityHidden(true)
		}
		.padding(20)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			RoundedRectangle(cornerRadius: 28, style: .continuous)
				.fill(
					LinearGradient(
						colors: [
							IntentTabInsightStyle.rankingSheetHeroGradientTop,
							IntentTabInsightStyle.rankingSheetHeroGradientBottom
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)
		)
	}
}

#Preview {
	InsightRankingSheetHeroHeaderView(
		statsLabel: "STATS",
		title: "直近1ヶ月の歌唱回数",
		subtitle: "あなたの最新のトレンドをチェックしましょう",
		systemImageName: "clock.fill"
	)
	.padding()
	.background(IntentTabInsightStyle.rankingSheetBackground)
}
