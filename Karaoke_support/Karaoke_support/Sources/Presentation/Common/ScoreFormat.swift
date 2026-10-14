import Foundation

/// 点数の表示。カラオケの採点（DAM 等）に合わせて小数第3位まで出し、四捨五入はしない。点数なしは「—」。
enum ScoreFormat {
	static let missing = "—"

	private static let style = FloatingPointFormatStyle<Double>.number
		.precision(.fractionLength(ScoreDigitInput.fractionDigits))
		.grouping(.never)

	/// 例: 92.345 / 92.500。点数なしは「—」。
	///
	/// 入力の時点で小数第3位までなので丸めは起きない。`Double` の表現誤差（92.34499…）だけを千分の一点に寄せて消す。
	static func text(_ score: Double?) -> String {
		guard let score else { return missing }
		return removingRepresentationError(score).formatted(style)
	}

	/// 前回比。例: +1.234 / -0.500。差も千分の一点単位なので丸めは起きない。
	static func signedText(_ delta: Double) -> String {
		removingRepresentationError(delta).formatted(style.sign(strategy: .always()))
	}

	/// 平均。割り算で小数第4位以下が出るため、小数第3位で切り捨てる（実際より高く見せない）。点数なしは「—」。
	static func averageText(_ average: Double?) -> String {
		guard let average else { return missing }
		// 92.345 の平均が 92.34499… になって 92.344 に切り捨てられないよう、表現誤差の分だけ足してから切り捨てる
		let truncated = ((average * 1000) + 1e-6).rounded(.towardZero) / 1000
		return truncated.formatted(style)
	}

	/// VoiceOver 用。例: 「スコア 92.345」「スコア なし」。
	static func accessibilityLabel(_ score: Double?) -> String {
		score.map { "スコア \(text($0))" } ?? "スコア なし"
	}

	private static func removingRepresentationError(_ value: Double) -> Double {
		(value * 1000).rounded() / 1000
	}
}
