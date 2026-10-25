import SwiftUI

/// 起動時に保存先の DB を開けなかったときに出す画面（#119）。
///
/// メモリ上の空の DB では起動しない。記録は端末に残っているので、アプリを消さないよう伝える。
struct DataLoadErrorView: View {
	var body: some View {
		ContentUnavailableView {
			Label("データを読み込めませんでした", systemImage: "exclamationmark.triangle")
		} description: {
			Text("これまでの記録は、この端末に残っています。アプリを削除せずに、TestFlight のフィードバックからお知らせください。")
		}
		.padding()
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.appBackgroundGradient()
	}
}

#Preview {
	DataLoadErrorView()
}
