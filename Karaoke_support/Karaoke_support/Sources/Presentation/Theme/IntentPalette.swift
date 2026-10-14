import SwiftUI

/// Intent の表示色。履歴のバッジと点数推移グラフの点で共有する。
enum IntentPalette {
	/// 記録シートの気分ボタンを選んだときの色（Shout はピンク、Emo は黄色、Practice は緑のネオン調）。
	static func accent(_ intent: Intent) -> Color {
		switch intent {
		case .shout: return AppColor.intentShoutAccent
		case .emo: return AppColor.intentEmoAccent
		case .practice: return AppColor.intentPracticeAccent
		}
	}

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
