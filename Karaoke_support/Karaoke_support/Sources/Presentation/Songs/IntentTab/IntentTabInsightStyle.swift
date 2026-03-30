import SwiftUI

/// インテントタブ・インサイトカード用のグラデーションと固定色（I-017）。
enum IntentTabInsightStyle {
	static let timeMachineGradientTop = Color(red: 0.56, green: 0.18, blue: 0.89)
	static let timeMachineGradientBottom = Color(red: 0.29, green: 0.0, blue: 0.88)
	static let myAnthemGradientTop = Color(red: 0.18, green: 0.12, blue: 0.42)
	static let myAnthemGradientBottom = Color(red: 0.08, green: 0.06, blue: 0.22)
	static let pageBackground = Color.black

	// MARK: ランキングシート（STATS / TOP 5）
	/// シート全体の背景（ワイヤーに近い極暗パープル）。
	static let rankingSheetBackground = Color(red: 11 / 255, green: 0, blue: 11 / 255)
	/// ヒーローカードのグラデ（ワインレッド〜深紫）。
	static let rankingSheetHeroGradientTop = Color(red: 0.38, green: 0.1, blue: 0.16)
	static let rankingSheetHeroGradientBottom = Color(red: 0.14, green: 0.05, blue: 0.2)
	/// ランキング行のカード面。
	static let rankingSheetRowBackground = Color(red: 0.14, green: 0.08, blue: 0.18)
}
