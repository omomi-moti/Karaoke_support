import SwiftUI

/// 記録を保存したあとに、画面の上に短く出す「保存しました」（ADR 0070）。出す・消すのは `RootView` が決める。
/// チェックは、保存直後のシートの見出しと同じ緑の丸にそろえる。
struct SavedToastView: View {
	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: "checkmark")
				.font(.callout.weight(.bold))
				.foregroundStyle(.white)
				.frame(width: 34, height: 34)
				.background(Circle().fill(Color.green))
				.accessibilityHidden(true)
			Text("保存しました")
				.font(.headline.weight(.heavy))
				.foregroundStyle(AppColor.textPrimary)
		}
		.padding(.leading, 10)
		.padding(.trailing, 20)
		.padding(.vertical, 10)
		.glassEffect(.regular, in: Capsule())
	}
}

#Preview {
	SavedToastView()
		.padding()
		.appBackgroundGradient()
}
