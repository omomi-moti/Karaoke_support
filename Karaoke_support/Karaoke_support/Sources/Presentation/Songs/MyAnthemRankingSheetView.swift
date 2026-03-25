import SwiftUI

/// マイアンセム（Intent 別ランキング）の一覧シート（I-017）。
struct MyAnthemRankingSheetView: View {
	let rankings: [MyAnthemRanking]
	let onSelectTrack: (SelectedTrack) -> Void

	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			List {
				ForEach(rankings) { block in
					if !block.byCount.isEmpty {
						Section {
							ForEach(Array(block.byCount.prefix(5).enumerated()), id: \.element.id) { index, row in
								Button {
									guard let track = row.makeSelectedTrack() else { return }
									dismiss()
									DispatchQueue.main.async {
										onSelectTrack(track)
									}
								} label: {
									rankingRowLabel(
										rank: index + 1,
										title: InsightTrackRowTitle.text(spotifyTrackId: row.spotifyTrackId, userEnteredName: row.userEnteredName),
										subtitle: "歌唱 \(row.countInPeriod) 回"
									)
								}
								.buttonStyle(.plain)
							}
						} header: {
							Text("\(Self.sectionTitle(for: block.intent)) — 歌った回数")
						}
					}

					if !block.byScore.isEmpty {
						Section {
							ForEach(Array(block.byScore.prefix(5).enumerated()), id: \.element.id) { index, row in
								Button {
									guard let track = row.makeSelectedTrack() else { return }
									dismiss()
									DispatchQueue.main.async {
										onSelectTrack(track)
									}
								} label: {
									rankingRowLabel(
										rank: index + 1,
										title: InsightTrackRowTitle.text(spotifyTrackId: row.spotifyTrackId, userEnteredName: row.userEnteredName),
										subtitle: "最高点 \(String(format: "%.1f", row.bestScore))"
									)
								}
								.buttonStyle(.plain)
							}
						} header: {
							Text("\(Self.sectionTitle(for: block.intent)) — 点数")
						}
					}
				}
			}
			.navigationTitle("マイアンセム")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("閉じる") { dismiss() }
				}
			}
		}
	}

	private static func sectionTitle(for intent: Intent) -> String {
		switch intent {
		case .shout: return "🔥 Shout"
		case .emo: return "🌙 Emo"
		case .practice: return "🎤 Practice"
		}
	}

	private func rankingRowLabel(rank: Int, title: String, subtitle: String) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 12) {
			Text("\(rank)")
				.font(.subheadline.monospacedDigit())
				.foregroundStyle(AppColor.textSecondary)
				.frame(width: 22, alignment: .trailing)
			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.body.weight(.medium))
					.foregroundStyle(AppColor.textPrimary)
				Text(subtitle)
					.font(.caption)
					.foregroundStyle(AppColor.textSecondary)
			}
			Spacer(minLength: 0)
		}
		.padding(.vertical, 2)
	}
}

#Preview {
	let tid = UUID()
	let countRow = InsightTrackCountRanking(
		id: tid,
		trackId: tid,
		spotifyTrackId: "spotify:track:preview",
		userEnteredName: "プレビュー曲",
		countInPeriod: 4
	)
	let scoreRow = InsightTrackScoreRanking(
		id: tid,
		trackId: tid,
		spotifyTrackId: "spotify:track:preview",
		userEnteredName: "プレビュー曲",
		bestScore: 93.5
	)
	return MyAnthemRankingSheetView(
		rankings: [
			MyAnthemRanking(intent: .shout, byCount: [countRow], byScore: [scoreRow]),
		],
		onSelectTrack: { _ in }
	)
}
