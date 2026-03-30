import SwiftUI

/// 履歴行の Intent 表示（ピル）。モックアップの Shout / Emo / Practice に対応。
struct HistoryIntentBadgeView: View {
	let intent: Intent

	var body: some View {
		Text(label)
			.font(.caption.weight(.semibold))
			.padding(.horizontal, 10)
			.padding(.vertical, 5)
			.background(background)
			.foregroundStyle(foreground)
			.clipShape(Capsule())
	}

	private var label: String {
		switch intent {
		case .shout: return "🔥 Shout"
		case .emo: return "🌙 Emo"
		case .practice: return "🎤 Practice"
		}
	}

	private var background: Color {
		switch intent {
		case .shout: return AppColor.badgeShoutBackground
		case .emo: return AppColor.badgeEmoBackground
		case .practice: return AppColor.badgePracticeBackground
		}
	}

	private var foreground: Color {
		switch intent {
		case .shout: return AppColor.badgeShoutForeground
		case .emo: return AppColor.badgeEmoForeground
		case .practice: return AppColor.badgePracticeForeground
		}
	}
}

#Preview {
	HStack {
		HistoryIntentBadgeView(intent: .shout)
		HistoryIntentBadgeView(intent: .emo)
		HistoryIntentBadgeView(intent: .practice)
	}
	.padding()
	.background(AppColor.backgroundGradientEnd)
}
