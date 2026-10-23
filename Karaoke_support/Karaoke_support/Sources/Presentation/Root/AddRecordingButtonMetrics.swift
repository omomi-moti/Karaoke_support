import SwiftUI

/// 右下の＋ボタン（新規記録）の寸法。`RootView` の配置と、一覧の下の余白で同じ値を使う。
enum AddRecordingButtonMetrics {
	static let size: CGFloat = 48
	/// タブバー・画面の右端からの距離
	static let margin: CGFloat = 16
}

extension View {
	/// 一番下までスクロールしたとき、最後の行が＋ボタンに隠れないように、スクロールの下に＋の分の余白を足す。
	func addRecordingButtonClearance() -> some View {
		contentMargins(.bottom, AddRecordingButtonMetrics.size + AddRecordingButtonMetrics.margin, for: .scrollContent)
	}
}
