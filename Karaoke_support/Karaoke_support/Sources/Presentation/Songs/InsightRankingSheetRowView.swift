import SwiftUI

/// ランキングシートの TOP 5 行（王冠 / 音符アイコン・右側に回数または点数）。
struct InsightRankingSheetRowView: View {
	let rank: Int
	let title: String
	/// V1 ではアーティストメタデータが無い場合が多い。`nil` / 空なら非表示。
	let artistLine: String?
	let rightValue: String
	let onTap: () -> Void

	var body: some View {
		Button(action: onTap) {
			HStack(alignment: .center, spacing: 14) {
				rankIcon
					.accessibilityHidden(true)
				VStack(alignment: .leading, spacing: 4) {
					Text("#\(rank)")
						.font(.caption.weight(.bold))
						.foregroundStyle(rank == 1 ? AppColor.accentScore : AppColor.textSecondary)
					Text(title)
						.font(.body.weight(.semibold))
						.foregroundStyle(AppColor.textPrimary)
						.multilineTextAlignment(.leading)
					if let artistLine, !artistLine.isEmpty {
						Text(artistLine)
							.font(.caption)
							.foregroundStyle(AppColor.textSecondary)
							.lineLimit(1)
					}
				}
				Spacer(minLength: 8)
				Text(rightValue)
					.font(.body.weight(.semibold))
					.foregroundStyle(rank == 1 ? AppColor.accentScore : AppColor.textPrimary)
					.monospacedDigit()
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 14)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(
				RoundedRectangle(cornerRadius: 22, style: .continuous)
					.fill(IntentTabInsightStyle.rankingSheetRowBackground)
			)
		}
		.buttonStyle(.plain)
		.accessibilityElement(children: .combine)
		.accessibilityLabel(accessibilityLabelText)
	}

	private var accessibilityLabelText: String {
		var parts: [String] = ["\(rank)位", title]
		if let artistLine, !artistLine.isEmpty {
			parts.append(artistLine)
		}
		parts.append(rightValue)
		return parts.joined(separator: "、")
	}

	@ViewBuilder
	private var rankIcon: some View {
		let size: CGFloat = 44
		switch rank {
		case 1:
			Image(systemName: "crown.fill")
				.font(.title3)
				.foregroundStyle(.white)
				.frame(width: size, height: size)
				.background(
					Circle()
						.fill(Color(red: 0.45, green: 0.2, blue: 0.75))
						.shadow(color: AppColor.accentScore.opacity(0.55), radius: 10, y: 2)
				)
		case 2:
			Image(systemName: "crown.fill")
				.font(.title3)
				.foregroundStyle(.white.opacity(0.9))
				.frame(width: size, height: size)
				.background(Circle().fill(Color.white.opacity(0.12)))
		case 3:
			Image(systemName: "crown.fill")
				.font(.title3)
				.foregroundStyle(Color(red: 1, green: 0.72, blue: 0.42))
				.frame(width: size, height: size)
				.background(Circle().fill(Color.white.opacity(0.08)))
		default:
			Image(systemName: "music.note")
				.font(.title3.weight(.medium))
				.foregroundStyle(AppColor.textSecondary)
				.frame(width: size, height: size)
				.background(Circle().fill(Color.white.opacity(0.06)))
		}
	}
}

#Preview {
	ScrollView {
		VStack(spacing: 12) {
			ForEach(1 ... 5, id: \.self) { r in
				InsightRankingSheetRowView(
					rank: r,
					title: "サンプル曲 \(r)",
					artistLine: r == 1 ? "アーティスト" : nil,
					rightValue: "\(12 - r)回",
					onTap: {}
				)
			}
		}
		.padding()
	}
	.background(IntentTabInsightStyle.rankingSheetBackground)
}
