import SwiftUI

/// Intent 表示のピル。履歴カードと点数推移グラフの凡例で共有する。
struct IntentBadgeView: View {
	let intent: Intent

	var body: some View {
		// 記録シートの気分ボタン・履歴の絞り込みチップと同じアイコン（SF Symbols）
		HStack(spacing: 4) {
			Image(systemName: IntentLabel.systemImage(intent))
				.accessibilityHidden(true)
			Text(IntentLabel.title(intent))
		}
			.font(.caption.weight(.semibold))
			.padding(.horizontal, 10)
			.padding(.vertical, 5)
			.background(IntentPalette.background(intent))
			.foregroundStyle(IntentPalette.foreground(intent))
			.clipShape(Capsule())
	}
}

#Preview {
	HStack {
		IntentBadgeView(intent: .shout)
		IntentBadgeView(intent: .emo)
		IntentBadgeView(intent: .practice)
	}
	.padding()
	.background(AppColor.backgroundGradientEnd)
}
