import SwiftUI

/// 歌唱データ 0 件向け Empty State（I-016）。履歴と選曲のタブで使う。
/// アカウントとバックアップのつなぎ先があるビルドでは、前の iPhone の記録をその場で取り込むボタンも出す。タブは移さない（ADR 0070・0071）。
struct SingingEmptyStateView: View {
	let onManualEntryTap: () -> Void
	#if DEBUG || BETA
	@Environment(\.accountRepository) private var accountRepository
	@Environment(\.backupRepository) private var backupRepository
	#endif

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
			#if DEBUG || BETA
			if let accountRepository, let backupRepository {
				RestoreFromEmptyStateView(accountRepository: accountRepository, backupRepository: backupRepository)
			}
			#endif
		}
		.padding(32)
	}
}

#Preview {
	SingingEmptyStateView(onManualEntryTap: {})
}

#if DEBUG || BETA
#Preview("取り込みのボタンあり") {
	SingingEmptyStateView(onManualEntryTap: {})
		.environment(\.accountRepository, PreviewAccountRepository())
		.environment(\.backupRepository, PreviewBackupRepository())
}
#endif
