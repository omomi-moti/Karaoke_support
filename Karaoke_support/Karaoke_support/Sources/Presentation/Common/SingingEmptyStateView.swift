import SwiftUI

/// 歌唱データ 0 件向け Empty State（I-016）。I-017 のインテントタブ等でも再利用する。
struct SingingEmptyStateView: View {
	let onManualEntryTap: () -> Void

	var body: some View {
		VStack(spacing: 16) {
			Image(systemName: "music.mic")
				.font(.system(size: 44))
				.foregroundStyle(AppColor.textSecondary)
			Text(SingingEmptyStateCopy.headline)
				.font(.title3.weight(.semibold))
				.foregroundStyle(AppColor.textPrimary)
				.multilineTextAlignment(.center)
			Button(action: onManualEntryTap) {
				Text(SingingEmptyStateCopy.manualEntryButtonTitle)
					.multilineTextAlignment(.center)
			}
			.buttonStyle(.borderedProminent)
			.tint(.pink.opacity(0.85))
		}
		.padding(32)
	}
}

#Preview {
	SingingEmptyStateView(onManualEntryTap: {})
}
