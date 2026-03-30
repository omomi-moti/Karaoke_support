import SwiftUI

/// インテントタブのインサイト（ヘッダー・タイムマシン・マイアンセム・統計）（I-017）。
struct IntentTabInsightView: View {
	@Bindable var viewModel: IntentTabViewModel
	let onSelectTrack: (SelectedTrack) -> Void
	let onNavigateToManualRecording: () -> Void

	@State private var showTimeMachineSheet = false
	@State private var showMyAnthemSheet = false

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
			} else {
				ScrollView {
					VStack(alignment: .leading, spacing: 12) {
						headerSection
						TimeMachineInsightCardView(onTapLookBack: { showTimeMachineSheet = true })
						MyAnthemInsightCardView(onTapListen: { showMyAnthemSheet = true })
						IntentTabMonthlyStatsRowView(
							monthSessionCount: viewModel.monthSessionCount,
							averageScore: viewModel.averageScoreThisMonth
						)
					}
					.padding(.horizontal, 16)
					.padding(.bottom, 24)
				}
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(IntentTabInsightStyle.pageBackground)
		.sheet(isPresented: $showTimeMachineSheet) {
			TimeMachineRankingSheetView(rankings: viewModel.timeMachineRanking, onSelectTrack: onSelectTrack)
		}
		.sheet(isPresented: $showMyAnthemSheet) {
			MyAnthemRankingSheetView(rankings: viewModel.myAnthemRankings, onSelectTrack: onSelectTrack)
		}
	}

	private var headerSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("あなたの歌唱データ")
				.font(.subheadline)
				.foregroundStyle(AppColor.textSecondary)
			Text("最高のパフォーマンスを振り返りましょう")
				.font(.title2.weight(.bold))
				.foregroundStyle(AppColor.textPrimary)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(.top, 4)
		.padding(.bottom, 8)
	}
}

#Preview {
	IntentTabContainerView(
		insightRepository: PreviewInsightRepository(),
		sessionRepository: PreviewSessionRepository(),
		onSelectTrack: { _ in },
		onNavigateToManualRecording: {}
	)
}
