import SwiftUI

struct RecordingSheetScoreSection: View {
	@Binding var score: ScoreDigitInput
	let isDisabled: Bool

	/// 見えない入力欄が持つ、打った数字だけの文字列（`92345`）。
	/// 入力欄の文字を `92.345` に書き換えながら打つと、速く打ったときに数字が抜けるため、表示は別の `Text` で整える。
	@State private var digits: String
	@FocusState private var isFocused: Bool

	init(score: Binding<ScoreDigitInput>, isDisabled: Bool) {
		_score = score
		self.isDisabled = isDisabled
		_digits = State(initialValue: score.wrappedValue.enteredDigits)
	}

	var body: some View {
		VStack(spacing: 12) {
			Text("カラオケスコア")
				.font(.subheadline.bold())
				.frame(maxWidth: .infinity)

			ZStack {
				TextField("", text: $digits)
					.keyboardType(.numberPad)
					.focused($isFocused)
					.opacity(0)
					.accessibilityHidden(true)
					.toolbar {
						// キーボードのツールバーはシート内のどの入力欄でも出るため、点数を入力中のときだけ出す
						ToolbarItemGroup(placement: .keyboard) {
							if isFocused {
								Spacer()
								Button("完了") { isFocused = false }
							}
						}
					}

				HStack(spacing: 4) {
					Text(score.displayText ?? "--.---")
						.font(.system(size: 56, weight: .bold, design: .rounded))
						.monospacedDigit()
						.foregroundStyle(score.value == nil ? AppColor.textTertiary : AppColor.accentScore)

					// 見えない入力欄の代わりのカーソル。打った数字は右端に入るので、右端で点滅させる。
					// 入力していないときも幅は取っておき、フォーカスの出入りで数字が横にずれないようにする
					RoundedRectangle(cornerRadius: 1.5)
						.fill(AppColor.accentScore)
						.frame(width: 3, height: 50)
						.phaseAnimator([true, false]) { cursor, isVisible in
							cursor.opacity(isVisible ? 1 : 0)
						} animation: { _ in
							.easeInOut(duration: 0.5)
						}
						.opacity(isFocused ? 1 : 0)
				}
				.frame(maxWidth: .infinity)
			}
			.contentShape(Rectangle())
			.onTapGesture {
				guard !isDisabled else { return }
				isFocused = true
			}
			.accessibilityElement(children: .ignore)
			.accessibilityLabel("カラオケスコア")
			.accessibilityValue(score.displayText.map { "\($0)点" } ?? "未入力")
			.accessibilityAddTraits(.isButton)
		}
		.padding()
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
		.onChange(of: digits) { _, newDigits in
			score.applyEditedText(newDigits)
			// 100 を超える桁・先頭の 0 など、読み直した結果と違うときだけ入力欄を戻す
			syncDigits()
		}
		.onChange(of: score) { _, _ in
			syncDigits()
		}
		.onChange(of: isDisabled) { _, disabled in
			if disabled { isFocused = false }
		}
	}

	private func syncDigits() {
		let normalized = score.enteredDigits
		if digits != normalized {
			digits = normalized
		}
	}
}

#Preview("未入力") {
	@Previewable @State var score = ScoreDigitInput()
	return RecordingSheetScoreSection(score: $score, isDisabled: false)
		.padding()
}

#Preview("入力済み") {
	@Previewable @State var score = ScoreDigitInput(score: 92.345)
	return RecordingSheetScoreSection(score: $score, isDisabled: false)
		.padding()
}
