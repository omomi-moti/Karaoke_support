import SwiftUI

struct HistoryRootView: View {
	var body: some View {
		EmptyPlaceholderView(
			title: "履歴（準備中）",
			message: "V1ではナビゲーション基盤のみ用意します。"
		)
		.navigationTitle("履歴")
		.navigationBarTitleDisplayMode(.inline)
	}
}

#Preview {
	NavigationStack {
		HistoryRootView()
	}
}

