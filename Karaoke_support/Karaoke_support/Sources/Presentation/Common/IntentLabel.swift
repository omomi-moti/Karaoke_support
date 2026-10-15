import Foundation

/// Intent の表示名とアイコン（SF Symbols）。記録シートの気分ボタン・履歴の絞り込みチップ・Intent バッジで共有する。
enum IntentLabel {
	static func title(_ intent: Intent) -> String {
		switch intent {
		case .shout: return "Shout"
		case .emo: return "Emo"
		case .practice: return "Practice"
		}
	}

	static func systemImage(_ intent: Intent) -> String {
		switch intent {
		case .shout: return "flame.fill"
		case .emo: return "moon.fill"
		case .practice: return "mic.fill"
		}
	}
}
