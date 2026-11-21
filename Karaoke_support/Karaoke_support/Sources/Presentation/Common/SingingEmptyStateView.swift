import SwiftUI

/// 歌唱データ 0 件向け Empty State（I-016）。履歴と選曲のタブで使う。
/// アカウントの欄があるビルドでは、前の iPhone の記録は設定から取り込めると文で案内する。タブは移さない（ADR 0061・0070）。
struct SingingEmptyStateView: View {
	let onManualEntryTap: () -> Void
	@Environment(\.isRestoreHintVisible) private var isRestoreHintVisible

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
			if isRestoreHintVisible {
				Text(SingingEmptyStateCopy.restoreHint)
					.font(.subheadline)
					.foregroundStyle(AppColor.textSecondary)
					.multilineTextAlignment(.center)
			}
		}
		.padding(32)
	}
}

#Preview {
	SingingEmptyStateView(onManualEntryTap: {})
}

#Preview("取り込みの案内あり") {
	SingingEmptyStateView(onManualEntryTap: {})
		.environment(\.isRestoreHintVisible, true)
}
