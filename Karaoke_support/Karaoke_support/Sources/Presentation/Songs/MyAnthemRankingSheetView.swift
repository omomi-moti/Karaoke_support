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
					Section {
						ForEach(Array(block.byCount.prefix(5).enumerated()), id: \.element.id) { index, row in
							Button {
								guard let track = row.makeSelectedTrack() else { return }
								dismiss()
								DispatchQueue.main.async {
									onSelectTrack(track)
								}
							} label: {
								HStack(alignment: .firstTextBaseline, spacing: 12) {
									Text("\(index + 1)")
										.font(.subheadline.monospacedDigit())
										.foregroundStyle(AppColor.textSecondary)
										.frame(width: 22, alignment: .trailing)
									VStack(alignment: .leading, spacing: 4) {
										Text(InsightTrackRowTitle.text(spotifyTrackId: row.spotifyTrackId, userEnteredName: row.userEnteredName))
											.font(.body.weight(.medium))
											.foregroundStyle(AppColor.textPrimary)
										Text("歌唱 \(row.countInPeriod) 回")
											.font(.caption)
											.foregroundStyle(AppColor.textSecondary)
									}
									Spacer(minLength: 0)
								}
								.padding(.vertical, 2)
							}
							.buttonStyle(.plain)
						}
					} header: {
						Text(Self.sectionTitle(for: block.intent))
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
}

#Preview {
	MyAnthemRankingSheetView(rankings: [], onSelectTrack: { _ in })
}
