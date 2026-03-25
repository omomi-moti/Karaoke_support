import SwiftUI

/// マイアンセム（Intent 別ランキング）の一覧シート（I-017）。
struct MyAnthemRankingSheetView: View {
	let rankings: [MyAnthemRanking]
	let onSelectTrack: (SelectedTrack) -> Void

	@Environment(\.dismiss) private var dismiss
	@State private var mode: MyAnthemSheetMode = .singCount

	var body: some View {
		NavigationStack {
			ZStack {
				IntentTabInsightStyle.rankingSheetBackground
					.ignoresSafeArea()
				ScrollView {
					VStack(alignment: .leading, spacing: 22) {
						InsightRankingSheetHeroHeaderView(
							statsLabel: "STATS",
							title: "マイアンセム",
							subtitle: heroSubtitle,
							systemImageName: "heart.text.square.fill"
						)
						Picker("表示モード", selection: $mode) {
							ForEach(MyAnthemSheetMode.allCases) { m in
								Text(m.title).tag(m)
							}
						}
						.pickerStyle(.segmented)
						.accessibilityLabel("マイアンセムの表示モード")

						if !hasContentForCurrentMode {
							Text(emptyMessageForMode)
								.font(.subheadline)
								.foregroundStyle(AppColor.textSecondary)
								.frame(maxWidth: .infinity)
								.padding(.vertical, 20)
						} else {
							ForEach(rankings) { block in
								switch mode {
								case .singCount:
									if !block.byCount.isEmpty {
										countSection(block: block)
									}
								case .bestScore:
									if !block.byScore.isEmpty {
										scoreSection(block: block)
									}
								}
							}
						}
					}
					.padding(.horizontal, 16)
					.padding(.bottom, 28)
				}
			}
			.navigationTitle("マイアンセム")
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

	private var heroSubtitle: String {
		switch mode {
		case .singCount:
			return "歌った回数で、感情ごとのランキングをチェックしましょう"
		case .bestScore:
			return "最高点で、感情ごとのランキングをチェックしましょう"
		}
	}

	private var hasContentForCurrentMode: Bool {
		switch mode {
		case .singCount:
			return rankings.contains { !$0.byCount.isEmpty }
		case .bestScore:
			return rankings.contains { !$0.byScore.isEmpty }
		}
	}

	private var emptyMessageForMode: String {
		switch mode {
		case .singCount:
			return "この期間・モードでは歌唱回数のデータがありません"
		case .bestScore:
			return "この期間・モードでは最高点のデータがありません"
		}
	}

	@ViewBuilder
	private func countSection(block: MyAnthemRanking) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			sectionCaption("\(Self.emojiTitle(for: block.intent)) — 歌った回数")
			VStack(spacing: 12) {
				ForEach(Array(block.byCount.prefix(5).enumerated()), id: \.element.id) { index, row in
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

	@ViewBuilder
	private func scoreSection(block: MyAnthemRanking) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			sectionCaption("\(Self.emojiTitle(for: block.intent)) — 点数")
			VStack(spacing: 12) {
				ForEach(Array(block.byScore.prefix(5).enumerated()), id: \.element.id) { index, row in
					InsightRankingSheetRowView(
						rank: index + 1,
						title: InsightTrackRowTitle.text(spotifyTrackId: row.spotifyTrackId, userEnteredName: row.userEnteredName),
						artistLine: nil,
						rightValue: String(format: "%.1f点", row.bestScore),
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

	private func sectionCaption(_ text: String) -> some View {
		Text(text)
			.font(.caption.weight(.semibold))
			.foregroundStyle(AppColor.textSecondary)
			.tracking(1)
	}

	private static func emojiTitle(for intent: Intent) -> String {
		switch intent {
		case .shout: return "🔥 Shout"
		case .emo: return "🌙 Emo"
		case .practice: return "🎤 Practice"
		}
	}
}

// MARK: - 表示モード

private enum MyAnthemSheetMode: String, CaseIterable, Identifiable {
	case singCount
	case bestScore

	var id: String { rawValue }

	var title: String {
		switch self {
		case .singCount: return "歌唱回数"
		case .bestScore: return "最高点"
		}
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
