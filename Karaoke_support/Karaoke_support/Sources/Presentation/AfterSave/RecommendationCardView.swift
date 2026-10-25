import SwiftUI

/// 保存直後のシートの提案カード（順位・曲名・理由の行）。タップでその曲を記録する（#115）。
struct RecommendationCardView: View {
	let rank: Int
	let title: String
	let reason: String
	let onTap: () -> Void

	var body: some View {
		Button(action: onTap) {
			HStack(spacing: 12) {
				Text("\(rank)")
					.font(.subheadline.weight(.heavy))
					.foregroundStyle(rank == 1 ? Color.white : AppColor.textPrimary)
					.frame(width: 34, height: 34)
					// ランキングシートの 1 位と同じ紫
					.background(Circle().fill(rank == 1 ? Color(red: 0.45, green: 0.2, blue: 0.75) : Color.primary.opacity(0.12)))
					.accessibilityHidden(true)
				VStack(alignment: .leading, spacing: 2) {
					Text(title)
						.font(.body.weight(.semibold))
						.foregroundStyle(AppColor.textPrimary)
						.multilineTextAlignment(.leading)
					Text(reason)
						.font(.caption)
						.foregroundStyle(AppColor.textSecondary)
				}
				Spacer(minLength: 8)
			}
			.padding(.horizontal, 14)
			.padding(.vertical, 12)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(AppColor.surfaceCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
			.contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		}
		.buttonStyle(.plain)
		.accessibilityElement(children: .combine)
		.accessibilityLabel("\(rank)位、\(title)、\(reason)")
		.accessibilityHint("この曲で記録します")
	}
}

#Preview {
	VStack(spacing: 8) {
		RecommendationCardView(rank: 1, title: "涙そうそう", reason: "2ヶ月ぶり", onTap: {})
		RecommendationCardView(rank: 2, title: "さよならララ", reason: "3週間ぶり", onTap: {})
	}
	.padding()
	.appBackgroundGradient()
}
