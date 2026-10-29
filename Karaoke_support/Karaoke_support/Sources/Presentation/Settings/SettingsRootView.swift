import SwiftUI

struct SettingsRootView: View {
	var body: some View {
		SettingsContainerView()
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.appBackgroundGradient()
			.navigationTitle("設定")
			.navigationBarTitleDisplayMode(.inline)
	}
}

#Preview {
	NavigationStack {
		SettingsRootView()
	}
}
