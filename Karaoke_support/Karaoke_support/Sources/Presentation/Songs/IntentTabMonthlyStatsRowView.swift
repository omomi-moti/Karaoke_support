import SwiftUI

/// 今月の総曲数・平均スコアの統計チップ（I-017）。
struct IntentTabMonthlyStatsRowView: View {
	let monthSessionCount: Int
	let averageScore: Double?

	var body: some View {
		HStack(spacing: 12) {
			statBubble(
				icon: "mic.fill",
				iconTint: Color.pink.opacity(0.95),
				value: "\(monthSessionCount)",
				label: "今月の総曲数"
			)
			statBubble(
				icon: "star.circle.fill",
				iconTint: Color.cyan.opacity(0.9),
				value: averageScore.map { String(format: "%.1f", $0) } ?? "—",
				label: "平均スコア"
			)
		}
	}

	private func statBubble(icon: String, iconTint: Color, value: String, label: String) -> some View {
		VStack(spacing: 10) {
			Image(systemName: icon)
				.font(.title2)
				.foregroundStyle(iconTint)
			Text(value)
				.font(.title.weight(.bold))
				.foregroundStyle(AppColor.textPrimary)
			Text(label)
				.font(.caption)
				.foregroundStyle(AppColor.textSecondary)
				.multilineTextAlignment(.center)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 20)
		.padding(.horizontal, 12)
		.background(
			RoundedRectangle(cornerRadius: 24, style: .continuous)
				.fill(Color(red: 0.08, green: 0.09, blue: 0.14))
				.overlay(
					RoundedRectangle(cornerRadius: 24, style: .continuous)
						.strokeBorder(AppColor.borderSubtle.opacity(0.6), lineWidth: 1)
				)
		)
	}
}

#Preview {
	IntentTabMonthlyStatsRowView(monthSessionCount: 24, averageScore: 92.4)
		.padding()
		.background(IntentTabInsightStyle.pageBackground)
}
