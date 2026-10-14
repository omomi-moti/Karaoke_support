import Foundation

/// 一覧・統計での点数の表示（小数第1位）。点数の入力は任意なので、点数なしは「—」にそろえる。
enum ScoreFormat {
	static let missing = "—"

	/// 例: 92.3。点数なしは「—」。
	static func text(_ score: Double?) -> String {
		score.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? missing
	}

	/// VoiceOver 用。例: 「スコア 92.3」「スコア なし」。
	static func accessibilityLabel(_ score: Double?) -> String {
		score.map { "スコア \(text($0))" } ?? "スコア なし"
	}
}
