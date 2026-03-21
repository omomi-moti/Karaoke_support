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
		case .shout: return Color(red: 0.45, green: 0.22, blue: 0.12).opacity(0.85)
		case .emo: return Color(red: 0.12, green: 0.35, blue: 0.38).opacity(0.9)
		case .practice: return Color(red: 0.14, green: 0.22, blue: 0.45).opacity(0.9)
		}
	}

	private var foreground: Color {
		switch intent {
		case .shout: return Color(red: 1.0, green: 0.62, blue: 0.35)
		case .emo: return Color(red: 0.55, green: 0.92, blue: 0.88)
		case .practice: return Color(red: 0.55, green: 0.72, blue: 1.0)
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
	.background(Color.black)
}
