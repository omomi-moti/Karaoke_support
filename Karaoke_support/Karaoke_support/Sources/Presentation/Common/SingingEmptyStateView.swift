import SwiftUI

/// 歌唱データ 0 件向け Empty State（I-016）。履歴と選曲のタブで使う。
/// 設定へ移れるときは、前の iPhone の記録を取り込む案内も出す（ADR 0061）。
struct SingingEmptyStateView: View {
	let onManualEntryTap: () -> Void
	@Environment(\.navigateToSettings) private var navigateToSettings

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
			if let navigateToSettings {
				Button(SingingEmptyStateCopy.restoreButtonTitle, action: navigateToSettings)
					.font(.subheadline)
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
		.environment(\.navigateToSettings) {}
}
