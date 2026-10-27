import SwiftUI

/// 保存直後のシートの提案カード（順位・曲名・理由の行）。タップでその曲を記録する（#115）。
/// 最新の記録にハートが付いた曲は、右端にハートを出す（#124）。
/// `rank` が `nil` のときは順位を出さず、`note` があれば理由の行の下に出す（挑戦中の曲・#131）。
struct RecommendationCardView: View {
	let rank: Int?
	let title: String
	let reason: String
	var note: String?
	var isWantAgain = false
	let onTap: () -> Void

	var body: some View {
		Button(action: onTap) {
			HStack(spacing: 12) {
				if let rank {
					Text("\(rank)")
						.font(.subheadline.weight(.heavy))
						.foregroundStyle(rank == 1 ? Color.white : AppColor.textPrimary)
						.frame(width: 34, height: 34)
						// ランキングシートの 1 位と同じ紫
						.background(Circle().fill(rank == 1 ? Color(red: 0.45, green: 0.2, blue: 0.75) : Color.primary.opacity(0.12)))
						.accessibilityHidden(true)
				}
				VStack(alignment: .leading, spacing: 2) {
					Text(title)
						.font(.body.weight(.semibold))
						.foregroundStyle(AppColor.textPrimary)
						.multilineTextAlignment(.leading)
					Text(reason)
						.font(.caption)
						.foregroundStyle(AppColor.textSecondary)
					if let note {
						Text(note)
							.font(.caption)
							.foregroundStyle(AppColor.textPrimary)
							.lineLimit(2)
							.multilineTextAlignment(.leading)
							.padding(.top, 2)
					}
				}
				Spacer(minLength: 8)
				if isWantAgain {
					Image(systemName: "heart.fill")
						.font(.body.weight(.semibold))
						.foregroundStyle(AppColor.accentScore)
						.accessibilityHidden(true)
				}
			}
			.padding(.horizontal, 14)
			.padding(.vertical, 12)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(AppColor.surfaceCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
			.contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		}
		.buttonStyle(.plain)
		.accessibilityElement(children: .combine)
		.accessibilityLabel(accessibilityText)
		.accessibilityHint("この曲で記録します")
	}

	private var accessibilityText: String {
		var parts = [title, reason]
		if let rank { parts.insert("\(rank)位", at: 0) }
		if let note { parts.append(note) }
		if isWantAgain { parts.append("また歌いたい") }
		return parts.joined(separator: "、")
	}
}

#Preview {
	VStack(spacing: 8) {
		RecommendationCardView(rank: 1, title: "涙そうそう", reason: "2ヶ月ぶり", isWantAgain: true, onTap: {})
		RecommendationCardView(rank: 2, title: "さよならララ", reason: "3週間ぶり", onTap: {})
		RecommendationCardView(rank: nil, title: "白日", reason: "歌い切れず ・ 1ヶ月前 ・ Shout", note: "サビのキーが高かった", onTap: {})
	}
	.padding()
	.appBackgroundGradient()
}
