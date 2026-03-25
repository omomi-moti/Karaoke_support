import SwiftUI

/// タイムマシン（過去1ヶ月・歌唱回数順）の一覧シート（I-017）。
struct TimeMachineRankingSheetView: View {
	let rankings: [InsightTrackCountRanking]
	let onSelectTrack: (SelectedTrack) -> Void

	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			ZStack {
				IntentTabInsightStyle.rankingSheetBackground
					.ignoresSafeArea()
				ScrollView {
					VStack(alignment: .leading, spacing: 20) {
						InsightRankingSheetHeroHeaderView(
							statsLabel: "STATS",
							title: "直近1ヶ月の歌唱回数",
							subtitle: "あなたの最新のトレンドをチェックしましょう",
							systemImageName: "clock.fill"
						)
						sectionTitle("ランキング TOP 5")
						if rankings.isEmpty {
							Text("まだデータがありません")
								.font(.subheadline)
								.foregroundStyle(AppColor.textSecondary)
								.frame(maxWidth: .infinity)
								.padding(.vertical, 24)
						} else {
							VStack(spacing: 12) {
								ForEach(Array(rankings.prefix(5).enumerated()), id: \.element.id) { index, row in
									InsightRankingSheetRowView(
										rank: index + 1,
										title: InsightTrackRowTitle.text(spotifyTrackId: row.spotifyTrackId, userEnteredName: row.userEnteredName),
										artistLine: nil,
										rightValue: "\(row.countInPeriod)回",
										onTap: {
											guard let track = row.makeSelectedTrack() else { return }
											dismiss()
											Task { @MainActor in
												onSelectTrack(track)
											}
										}
									)
								}
							}
						}
					}
					.padding(.horizontal, 16)
					.padding(.bottom, 28)
				}
			}
			.navigationTitle("タイムマシン")
			.navigationBarTitleDisplayMode(.inline)
			.toolbarBackground(IntentTabInsightStyle.rankingSheetBackground, for: .navigationBar)
			.toolbarColorScheme(.dark, for: .navigationBar)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("閉じる") { dismiss() }
						.foregroundStyle(AppColor.textPrimary)
				}
			}
		}
	}

	private func sectionTitle(_ text: String) -> some View {
		Text(text)
			.font(.caption.weight(.semibold))
			.foregroundStyle(AppColor.textSecondary)
			.tracking(2)
	}
}

#Preview {
	let id = UUID()
	let sample = InsightTrackCountRanking(
		id: id,
		trackId: id,
		spotifyTrackId: nil,
		userEnteredName: "プレビュー曲",
		countInPeriod: 12
	)
	return TimeMachineRankingSheetView(rankings: [sample], onSelectTrack: { _ in })
}
