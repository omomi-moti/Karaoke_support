import Foundation
import Testing

@testable import Karaoke_support

@Suite("ScoreDigitInput")
struct ScoreDigitInputTests {

	/// 入力欄と同じく、打った数字の末尾に 1 文字ずつ足して読み直す。
	private func typed(_ keys: String, from start: ScoreDigitInput = ScoreDigitInput()) -> ScoreDigitInput {
		var input = start
		for key in keys {
			input.applyEditedText(input.enteredDigits + String(key))
		}
		return input
	}

	/// 入力欄の ⌫ と同じく、打った数字の最後の 1 文字を消して読み直す。
	private func deletingLast(_ input: ScoreDigitInput) -> ScoreDigitInput {
		var result = input
		result.applyEditedText(String(input.enteredDigits.dropLast()))
		return result
	}

	// MARK: 右詰め

	@Test("未入力は値も表示も nil")
	func emptyHasNoValue() {
		let input = ScoreDigitInput()
		#expect(input.value == nil)
		#expect(input.displayText == nil)
	}

	@Test(
		"打った数字が右から押し出される",
		arguments: [
			("9", "0.009"),
			("92", "0.092"),
			("923", "0.923"),
			("9234", "9.234"),
			("92345", "92.345"),
			("100000", "100.000"),
		]
	)
	func digitsShiftInFromTheRight(keys: String, expected: String) {
		#expect(typed(keys).displayText == expected)
	}

	@Test("92345 と打つと値は 92.345")
	func valueMatchesDisplay() {
		#expect(typed("92345").value == 92.345)
	}

	@Test("打った数字だけの形は先頭の 0 を含まない")
	func enteredDigitsHasNoLeadingZeros() {
		#expect(ScoreDigitInput().enteredDigits == "")
		#expect(typed("09").enteredDigits == "9")
		#expect(ScoreDigitInput(score: 92.5).enteredDigits == "92500")
	}

	@Test("数字以外の文字は読み飛ばす")
	func ignoresNonDigits() {
		var input = ScoreDigitInput()
		input.applyEditedText("9a2.3 4-5")
		#expect(input.displayText == "92.345")
	}

	@Test("先頭の 0 は読み飛ばし、0 だけなら未入力のまま")
	func leadingZerosAreIgnored() {
		#expect(typed("0").value == nil)
		#expect(typed("09").displayText == "0.009")
	}

	// MARK: 上限

	@Test("100.000 の次に打った数字は無視する")
	func cannotExceedOneHundred() {
		#expect(typed("1000000").displayText == "100.000")
	}

	@Test("100.000 を超える桁は打てず、超えない入力は続けられる")
	func rejectsOnlyDigitsThatExceedMax() {
		let tenPoints = typed("10000")
		#expect(typed("1", from: tenPoints).displayText == "10.000")  // 100.001 になるので無視
		#expect(typed("0", from: tenPoints).displayText == "100.000")
	}

	// MARK: 消去

	@Test("⌫ で最後の 1 桁を消す")
	func deleteLastRemovesOneDigit() {
		#expect(deletingLast(typed("92345")).displayText == "9.234")
	}

	@Test("1 桁のときに ⌫ を押すと未入力に戻る")
	func deletingLastDigitBecomesEmpty() {
		#expect(deletingLast(typed("1")).value == nil)
	}

	@Test("0 点（0.000）の表示から 1 文字消しても 0.000 で止まらず未入力に戻る")
	func deletingFromZeroDisplayBecomesEmpty() {
		var input = ScoreDigitInput(score: 0)
		input.applyEditedText("0.00")
		#expect(input.value == nil)
	}

	@Test("入力欄を空にすると未入力に戻る")
	func emptyTextBecomesEmpty() {
		var input = typed("92345")
		input.applyEditedText("")
		#expect(input.value == nil)
	}

	// MARK: 既存の点数から始める

	@Test(
		"既存の点数を小数第3位までの表示にする",
		arguments: [
			(92.5, "92.500"),
			(92.345, "92.345"),
			(0.0, "0.000"),
			(100.0, "100.000"),
			(88.8888, "88.889"),  // 小数第4位は四捨五入
		]
	)
	func initFromScore(score: Double, expected: String) {
		#expect(ScoreDigitInput(score: score).displayText == expected)
	}

	@Test("既存の点数から始めても、続けて ⌫ や数字で直せる")
	func editingFromExistingScore() {
		let edited = typed("1", from: deletingLast(ScoreDigitInput(score: 92.5)))
		#expect(edited.displayText == "92.501")
	}
}
