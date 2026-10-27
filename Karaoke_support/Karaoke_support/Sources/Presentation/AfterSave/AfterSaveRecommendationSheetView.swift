import SwiftUI

/// 保存直後のシート。保存した記録を確かめ、次の 1 曲の候補を出す（#115）。「もっと見る」で選曲画面へ移る（#126）。
struct AfterSaveRecommendationSheetView: View {
	let content: AfterSaveSheetContent
	let onSelect: (TrackRecommendation) -> Void
	let onShowMore: () -> Void
	let onLater: () -> Void

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				savedHeader

				Divider()

				VStack(alignment: .leading, spacing: 12) {
					Text("次はこの曲？")
						.font(.title2.weight(.heavy))
						.foregroundStyle(AppColor.textPrimary)
						.fixedSize(horizontal: false, vertical: true)
					HStack(spacing: 10) {
						IntentBadgeView(intent: content.saved.intent)
						Text(isShowingChallenges ? "練習中の曲から選んでいます" : "直前の気分から選んでいます")
							.font(.caption)
							.foregroundStyle(AppColor.textSecondary)
					}
				}

				VStack(spacing: 8) {
					ForEach(Array(content.recommendations.enumerated()), id: \.element.stats.trackId) { index, recommendation in
						RecommendationCardView(
							rank: isShowingChallenges ? nil : index + 1,
							title: TrackDisplayTitle.primary(
								spotifyTrackId: recommendation.stats.spotifyTrackId,
								userEnteredName: recommendation.stats.userEnteredName
							),
							reason: isShowingChallenges
								? RecommendationReasonFormat.challenge(recommendation)
								: RecommendationReasonFormat.sinceLastSung(days: recommendation.daysSinceLastSung),
							note: isShowingChallenges && !recommendation.stats.latestIsCompleted ? recommendation.stats.latestMemo : nil,
							isWantAgain: recommendation.stats.latestWantAgain,
							onTap: { onSelect(recommendation) }
						)
					}
				}

				Button(action: onShowMore) {
					HStack(spacing: 6) {
						Text("もっと見る")
						Image(systemName: "chevron.right")
							.font(.subheadline.weight(.bold))
							.accessibilityHidden(true)
					}
					.font(.body.weight(.semibold))
					.frame(maxWidth: .infinity, minHeight: 44)
				}
				.buttonStyle(.bordered)
				.tint(AppColor.accentScore)
				.accessibilityHint("選曲画面で、ほかの曲も見ます")

				Button(action: onLater) {
					Text("あとで")
						.font(.body.weight(.semibold))
						.foregroundStyle(AppColor.textSecondary)
						.frame(maxWidth: .infinity, minHeight: 44)
						.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
			}
			.padding(.horizontal, 20)
			.padding(.top, 28)
			.padding(.bottom, 16)
		}
		.appBackgroundGradient()
		.presentationDetents([.medium, .large])
		.presentationDragIndicator(.visible)
	}

	/// Practice で保存したときは、練習中の曲と歌い切れなかった曲を、選曲画面の Practice と同じ形で出す（#131）。
	private var isShowingChallenges: Bool { content.saved.intent == .practice }

	private var savedHeader: some View {
		HStack(spacing: 12) {
			Image(systemName: "checkmark")
				.font(.body.weight(.bold))
				.foregroundStyle(.white)
				.frame(width: 40, height: 40)
				.background(Circle().fill(Color.green))
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: 2) {
				Text("保存しました")
					.font(.headline.weight(.heavy))
					.foregroundStyle(AppColor.textPrimary)
				Text(savedSummaryLine)
					.font(.footnote)
					.foregroundStyle(AppColor.textSecondary)
			}
		}
		.accessibilityElement(children: .combine)
	}

	/// 例:「Pretender ・ Emo ・ 91.250」。点数なしなら点数は出さない。
	private var savedSummaryLine: String {
		let saved = content.saved
		var parts = [saved.trackTitle, IntentLabel.title(saved.intent)]
		if saved.score != nil {
			parts.append(ScoreFormat.text(saved.score))
		}
		return parts.joined(separator: " ・ ")
	}
}

#Preview {
	let stats: [(String, Int, Bool)] = [("涙そうそう", 60, true), ("さよならララ", 21, false)]
	let recommendations = stats.map { name, days, wantAgain in
		TrackRecommendation(
			stats: TrackSingingStats(
				trackId: UUID(),
				spotifyTrackId: nil,
				userEnteredName: name,
				latestIntent: .emo,
				lastPerformedAt: .now,
				bestScore: 90,
				sessionCount: 3,
				latestWantAgain: wantAgain
			),
			score: 0,
			daysSinceLastSung: days
		)
	}
	Color.clear
		.sheet(isPresented: .constant(true)) {
			AfterSaveRecommendationSheetView(
				content: AfterSaveSheetContent(
					saved: SavedRecording(
						sessionId: UUID(),
						trackId: UUID(),
						trackTitle: "Pretender",
						intent: .emo,
						score: 91.25,
						isNewRecording: true
					),
					recommendations: recommendations
				),
				onSelect: { _ in },
				onShowMore: {},
				onLater: {}
			)
		}
}
