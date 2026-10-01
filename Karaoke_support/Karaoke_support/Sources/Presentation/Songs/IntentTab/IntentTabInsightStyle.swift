import SwiftUI

/// インテントタブ・インサイトカード用のグラデーションと固定色（I-017）。
///
/// 色付きカード（タイムマシン・マイアンセム・ランキングのヒーロー）はライト／ダーク共通の固定色。
/// ページ・シート背景や行の面は Color Set でライト／ダークを切り替える。
///
/// 固定色カードの中の文字は、どちらのモードでも明るく見える必要がある:
/// - 白リテラルで書く（`TimeMachineInsightCardView` / `MyAnthemInsightCardView`）
/// - `AppColor` のトークンを使う場合は、カードに `.environment(\.colorScheme, .dark)` を付けて常にダーク側で解決させる（`InsightRankingSheetHeroHeaderView`）
enum IntentTabInsightStyle {
	static let timeMachineGradientTop = Color(red: 0.56, green: 0.18, blue: 0.89)
	static let timeMachineGradientBottom = Color(red: 0.29, green: 0.0, blue: 0.88)
	static let myAnthemGradientTop = Color(red: 0.18, green: 0.12, blue: 0.42)
	static let myAnthemGradientBottom = Color(red: 0.08, green: 0.06, blue: 0.22)
	/// 今月の統計チップのカード面。
	static let statsCardBackground = Color(.appInsightStatsCardBackground)
	/// 平均スコアのアイコン。
	static let statsScoreIcon = Color(.appInsightStatsScoreIcon)

	// MARK: ランキングシート（STATS / TOP 5）
	/// シート全体の背景（ダーク: 極暗パープル / ライト: 淡いラベンダー）。
	static let rankingSheetBackground = Color(.appInsightSheetBackground)
	/// ヒーローカードのグラデ（ワインレッド〜深紫）。
	static let rankingSheetHeroGradientTop = Color(red: 0.38, green: 0.1, blue: 0.16)
	static let rankingSheetHeroGradientBottom = Color(red: 0.14, green: 0.05, blue: 0.2)
	/// ランキング行のカード面。
	static let rankingSheetRowBackground = Color(.appInsightSheetRowBackground)
	/// 2 位（銀）・3 位（銅）の王冠。
	static let rankSilver = Color(.appInsightRankSilver)
	static let rankBronze = Color(.appInsightRankBronze)
}
