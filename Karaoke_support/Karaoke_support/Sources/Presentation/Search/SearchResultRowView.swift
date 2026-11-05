import SwiftUI

/// 検索タブの 1 行（#142）。右端の＋は、記録を追加する＋ボタンと同じ色で「この曲で記録する」を表す。
struct SearchResultRowView: View {
	let item: SearchResultDisplayItem
	let onTap: () -> Void

	var body: some View {
		Button(action: onTap) {
			HStack(spacing: 12) {
				VStack(alignment: .leading, spacing: 2) {
					HStack(spacing: 6) {
						Text(item.title)
							.font(.body.weight(.semibold))
							.foregroundStyle(AppColor.textPrimary)
							.lineLimit(1)
						if item.isWantAgain {
							Image(systemName: "heart.fill")
								.font(.caption)
								.foregroundStyle(AppColor.accentScore)
						}
					}
					Text(item.subtitle)
						.font(.subheadline)
						.foregroundStyle(AppColor.textSecondary)
						.lineLimit(1)
				}
				Spacer(minLength: 8)
				Image(systemName: "plus.circle.fill")
					.font(.title2)
					.foregroundStyle(AppColor.addButton)
			}
			.padding(.vertical, 4)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.accessibilityElement(children: .combine)
		.accessibilityLabel(accessibilityText)
		.accessibilityHint("この曲で記録します")
	}

	private var accessibilityText: String {
		var parts = [item.title, item.subtitle]
		if item.isWantAgain { parts.append("また歌いたい") }
		return parts.joined(separator: "、")
	}
}

#Preview("Row") {
	List {
		SearchResultRowView(
			item: SearchResultDisplayItem(
				stats: TrackSingingStats(
					trackId: UUID(),
					spotifyTrackId: nil,
					userEnteredName: "アイドル",
					latestIntent: .shout,
					lastPerformedAt: .now.addingTimeInterval(-5 * 86_400),
					bestScore: 92.5,
					sessionCount: 4,
					latestWantAgain: true
				),
				now: .now,
				calendar: .current
			),
			onTap: {}
		)
		SearchResultRowView(
			item: SearchResultDisplayItem(track: Track(userEnteredName: "記録を消した曲"), now: .now, calendar: .current),
			onTap: {}
		)
	}
}
