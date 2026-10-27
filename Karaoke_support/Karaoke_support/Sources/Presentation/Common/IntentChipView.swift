import SwiftUI

/// 気分のチップ 1 つ分。履歴の絞り込みと選曲画面の気分の切り替えで使う。
struct IntentChipView: View {
	let title: String
	let systemImage: String?
	let accent: Color
	let isSelected: Bool
	var glowsWhenSelected = true
	/// 選んだときの枠の色。`nil` なら `accent`。
	var selectedBorderColor: Color?
	let accessibilityLabel: String
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack(spacing: 4) {
				// 記録シートの気分ボタンと同じアイコン。選んだときはアイコンだけ気分の色にする
				if let systemImage {
					Image(systemName: systemImage)
						.foregroundStyle(isSelected ? accent : AppColor.foregroundSubtle)
						.accessibilityHidden(true)
				}
				Text(title)
			}
				.font(.subheadline.weight(.semibold))
				// アイコンの分だけ広がるので、標準の文字サイズで 4 つが横幅に収まるよう左右を 14pt から詰める
				.padding(.horizontal, 10)
				.padding(.vertical, 8)
				.background(
					Capsule()
						.fill(isSelected ? accent.opacity(0.2) : AppColor.filterChipUnselectedBackground)
				)
				.overlay(
					// 選択の切り替えでチップの大きさが変わらないよう、枠は常に内側に描いて色だけ変える
					Capsule()
						.strokeBorder(isSelected ? (selectedBorderColor ?? accent) : Color.clear, lineWidth: 1.5)
				)
				.foregroundStyle(isSelected ? AppColor.textPrimary : AppColor.foregroundSubtle)
				.shadow(color: isSelected && glowsWhenSelected ? accent.opacity(0.6) : .clear, radius: 6)
		}
		.buttonStyle(.plain)
		.accessibilityLabel(accessibilityLabel)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}
}

#Preview {
	HStack {
		IntentChipView(title: "Emo", systemImage: "moon.fill", accent: IntentPalette.accent(.emo), isSelected: true, accessibilityLabel: "Emo", action: {})
		IntentChipView(title: "Shout", systemImage: "flame.fill", accent: IntentPalette.accent(.shout), isSelected: false, accessibilityLabel: "Shout", action: {})
	}
	.padding()
	.background(AppColor.backgroundGradientEnd)
}
