import SwiftUI

/// 画面共通のダークグラデーション背景（I-R007）。
struct AppBackgroundGradientView: View {
	var body: some View {
		LinearGradient(
			colors: [
				AppColor.backgroundGradientStart,
				AppColor.backgroundGradientEnd,
			],
			startPoint: .top,
			endPoint: .bottom
		)
		.ignoresSafeArea()
	}
}

extension View {
	/// `AppBackgroundGradientView` を `.background()` として適用する。
	func appBackgroundGradient() -> some View {
		background(AppBackgroundGradientView())
	}
}

#Preview {
	AppBackgroundGradientView()
}
