import SwiftUI

/// Intent の表示色。履歴のバッジと点数推移グラフの点で共有する。
enum IntentPalette {
	static func background(_ intent: Intent) -> Color {
		switch intent {
		case .shout: return AppColor.badgeShoutBackground
		case .emo: return AppColor.badgeEmoBackground
		case .practice: return AppColor.badgePracticeBackground
		}
	}

	static func foreground(_ intent: Intent) -> Color {
		switch intent {
		case .shout: return AppColor.badgeShoutForeground
		case .emo: return AppColor.badgeEmoForeground
		case .practice: return AppColor.badgePracticeForeground
		}
	}
}
