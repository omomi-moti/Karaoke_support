import SwiftUI

struct SettingsRootView: View {
	var body: some View {
		EmptyPlaceholderView(
			title: "設定（準備中）",
			message: "V1ではプレースホルダー表示です。"
		)
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

