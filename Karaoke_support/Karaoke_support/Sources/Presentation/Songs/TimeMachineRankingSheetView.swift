import SwiftUI

/// タイムマシン（過去1ヶ月・歌唱回数順）の一覧シート（I-017）。
struct TimeMachineRankingSheetView: View {
	let rankings: [InsightTrackCountRanking]
	let onSelectTrack: (SelectedTrack) -> Void

	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			List {
				ForEach(Array(rankings.enumerated()), id: \.element.id) { index, row in
					Button {
						guard let track = row.makeSelectedTrack() else { return }
						dismiss()
						DispatchQueue.main.async {
							onSelectTrack(track)
						}
					} label: {
						HStack(alignment: .firstTextBaseline, spacing: 12) {
							Text("\(index + 1)")
								.font(.headline.monospacedDigit())
								.foregroundStyle(AppColor.textSecondary)
								.frame(width: 28, alignment: .trailing)
							VStack(alignment: .leading, spacing: 4) {
								Text(InsightTrackRowTitle.text(spotifyTrackId: row.spotifyTrackId, userEnteredName: row.userEnteredName))
									.font(.body.weight(.medium))
									.foregroundStyle(AppColor.textPrimary)
								Text("\(row.countInPeriod) 回")
									.font(.caption)
									.foregroundStyle(AppColor.textSecondary)
							}
							Spacer(minLength: 0)
						}
						.padding(.vertical, 4)
					}
					.buttonStyle(.plain)
				}
			}
			.navigationTitle("タイムマシン")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("閉じる") { dismiss() }
				}
			}
		}
	}
}

#Preview {
	TimeMachineRankingSheetView(rankings: [], onSelectTrack: { _ in })
}
