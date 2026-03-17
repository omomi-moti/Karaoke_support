import SwiftUI

struct SettingsRootView: View {
	var body: some View {
		EmptyPlaceholderView(
			title: "設定（準備中）",
			message: "V1ではプレースホルダー表示です。"
		)
		.navigationTitle("設定")
		.navigationBarTitleDisplayMode(.inline)
	}
}

#Preview {
	NavigationStack {
		SettingsRootView()
	}
}

