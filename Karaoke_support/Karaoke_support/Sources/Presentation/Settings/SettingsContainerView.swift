import SwiftUI

/// 設定の中身を出す。
struct SettingsContainerView: View {
	var body: some View {
		List {
			Section {
				Label("記録はこの iPhone の中にだけ保存されます", systemImage: "iphone")
			} header: {
				Text("データについて")
			} footer: {
				Text("記録・気分・メモは外部に送信されません。アプリを削除すると、記録も消えます。")
			}
		}
		.scrollContentBackground(.hidden)
	}
}

#Preview {
	SettingsContainerView()
}
