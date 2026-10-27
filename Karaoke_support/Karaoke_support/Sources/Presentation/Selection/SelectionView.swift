import SwiftUI

/// 選曲画面（#126）。気分のチップ、「また歌いたい」、「今の気分に合う曲」を並べる。
struct SelectionView: View {
	@Bindable var viewModel: SelectionViewModel
	let onSelect: (TrackRecommendation, Intent) -> Void
	let onNavigateToManualRecording: () -> Void

	var body: some View {
		Group {
			if viewModel.shouldShowBlockingLoad {
				ProgressView()
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else if let message = viewModel.loadErrorMessage {
				VStack(spacing: 16) {
					Text(message)
						.font(.subheadline)
						.foregroundStyle(AppColor.semanticError)
						.multilineTextAlignment(.center)
					Button("再試行") {
						Task { await viewModel.load() }
					}
					.buttonStyle(.borderedProminent)
					.tint(.pink.opacity(0.85))
				}
				.padding(24)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else if !viewModel.hasSingingData {
				SingingEmptyStateView(onManualEntryTap: onNavigateToManualRecording)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
				ScrollView {
					VStack(alignment: .leading, spacing: 20) {
						moodBar
						let sections = viewModel.sections
						if sections.isEmpty {
							noCandidates
						} else {
							if !sections.wantAgain.isEmpty {
								section(title: "また歌いたい", systemImage: "heart.fill", recommendations: sections.wantAgain)
							}
							if !sections.moodMatched.isEmpty {
								section(title: "今の気分に合う曲", systemImage: nil, recommendations: sections.moodMatched)
							}
						}
					}
					.padding(.horizontal, 16)
					.padding(.top, 8)
					.padding(.bottom, 24)
				}
				.addRecordingButtonClearance()
			}
		}
	}

	private var moodBar: some View {
		HStack(spacing: 8) {
			ForEach(Intent.allCases, id: \.self) { intent in
				IntentChipView(
					title: IntentLabel.title(intent),
					systemImage: IntentLabel.systemImage(intent),
					accent: IntentPalette.accent(intent),
					isSelected: viewModel.mood == intent,
					accessibilityLabel: "気分 \(IntentLabel.title(intent))",
					action: { viewModel.mood = intent }
				)
			}
		}
	}

	private func section(title: String, systemImage: String?, recommendations: [TrackRecommendation]) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(spacing: 6) {
				if let systemImage {
					Image(systemName: systemImage)
						.foregroundStyle(AppColor.accentScore)
						.accessibilityHidden(true)
				}
				Text(title)
					.font(.headline)
					.foregroundStyle(AppColor.textPrimary)
			}
			.accessibilityElement(children: .combine)
			.accessibilityAddTraits(.isHeader)

			ForEach(Array(recommendations.enumerated()), id: \.element.stats.trackId) { index, recommendation in
				RecommendationCardView(
					rank: index + 1,
					title: TrackDisplayTitle.primary(
						spotifyTrackId: recommendation.stats.spotifyTrackId,
						userEnteredName: recommendation.stats.userEnteredName
					),
					reason: reason(for: recommendation),
					isWantAgain: recommendation.stats.latestWantAgain,
					onTap: { onSelect(recommendation, viewModel.mood) }
				)
			}
		}
	}

	private func reason(for recommendation: TrackRecommendation) -> String {
		if recommendation.stats.latestIntent == viewModel.mood {
			return RecommendationReasonFormat.sinceLastSung(days: recommendation.daysSinceLastSung)
		}
		return RecommendationReasonFormat.sinceLastSung(days: recommendation.daysSinceLastSung, intent: recommendation.stats.latestIntent)
	}

	private var noCandidates: some View {
		VStack(spacing: 16) {
			Text("記録が増えると、ここに曲が出ます")
				.font(.subheadline)
				.foregroundStyle(AppColor.textSecondary)
				.multilineTextAlignment(.center)
			Button(SingingEmptyStateCopy.manualEntryButtonTitle, action: onNavigateToManualRecording)
				.buttonStyle(.borderedProminent)
				.tint(.pink.opacity(0.85))
		}
		.frame(maxWidth: .infinity)
		.padding(.top, 32)
	}
}

#Preview {
	SelectionContainerView(
		trackStatsRepository: PreviewTrackStatsRepository(),
		onSelect: { _, _ in },
		onNavigateToManualRecording: {}
	)
	.appBackgroundGradient()
}
