import SwiftUI

/// Intent 表示のピル。履歴カードと点数推移グラフの凡例で共有する。
struct IntentBadgeView: View {
	let intent: Intent

	var body: some View {
		Text(label)
			.font(.caption.weight(.semibold))
			.padding(.horizontal, 10)
			.padding(.vertical, 5)
			.background(IntentPalette.background(intent))
			.foregroundStyle(IntentPalette.foreground(intent))
			.clipShape(Capsule())
	}

	private var label: String {
		switch intent {
		case .shout: return "🔥 Shout"
		case .emo: return "🌙 Emo"
		case .practice: return "🎤 Practice"
		}
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
