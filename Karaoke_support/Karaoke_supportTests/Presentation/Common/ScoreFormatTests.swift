import Foundation
import Testing

@testable import Karaoke_support

@Suite("ScoreFormat")
struct ScoreFormatTests {

	@Test(
		"点数は小数第3位までそのまま出す（四捨五入しない）",
		arguments: [
			(92.345, "92.345"),
			(92.35, "92.350"),
			(92.5, "92.500"),  // スライダー時代の記録
			(100.0, "100.000"),
			(0.0, "0.000"),
			(99.999, "99.999"),
		]
	)
	func textShowsThreeDecimals(score: Double, expected: String) {
		#expect(ScoreFormat.text(score) == expected)
	}

	@Test("入力経路（千分の一点 ÷ 1000）の値は打った数字のまま出る")
	func textMatchesTypedDigits() {
		for thousandths in [92345, 88501, 1, 99999, 50005] {
			var input = ScoreDigitInput()
			input.applyEditedText(String(thousandths))
			#expect(ScoreFormat.text(input.value) == input.displayText)
		}
	}

	@Test("点数なしは「—」")
	func missingScoreIsDash() {
		#expect(ScoreFormat.text(nil) == "—")
		#expect(ScoreFormat.averageText(nil) == "—")
		#expect(ScoreFormat.accessibilityLabel(nil) == "スコア なし")
	}

	@Test("前回比は符号付きで、引き算の表現誤差で桁がずれない")
	func signedTextHasSignAndIgnoresRepresentationError() {
		#expect(ScoreFormat.signedText(92.345 - 92.344) == "+0.001")
		#expect(ScoreFormat.signedText(88.0 - 88.5) == "-0.500")
	}

	private static let averageCases: [(average: Double, expected: String)] = [
		((80.0 + 90.0 + 85.001) / 3, "85.000"),  // 85.000333…
		((92.346 + 92.345) / 2, "92.345"),  // 92.3455
		((92.345 + 92.345) / 2, "92.345"),  // 表現誤差で 92.344 にならない
		(99.9999, "99.999"),  // 100.000 に見せない
	]

	@Test("平均は小数第3位で切り捨てる", arguments: averageCases)
	func averageIsTruncated(average: Double, expected: String) {
		#expect(ScoreFormat.averageText(average) == expected)
	}
}
