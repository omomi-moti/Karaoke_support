import SwiftUI

struct SettingsRootView: View {
	#if DEBUG || BETA
	@Environment(\.accountRepository) private var accountRepository
	@Environment(\.backupRepository) private var backupRepository
	#endif

	var body: some View {
		settingsContainer
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.appBackgroundGradient()
			.navigationTitle("設定")
			.navigationBarTitleDisplayMode(.inline)
	}

	private var settingsContainer: SettingsContainerView {
		#if DEBUG || BETA
		SettingsContainerView(accountRepository: accountRepository, backupRepository: backupRepository)
		#else
		SettingsContainerView()
		#endif
	}
}

#Preview {
	NavigationStack {
		SettingsRootView()
	}
}
