import SwiftUI

struct RecordingSheetScoreSection: View {
	@Binding var score: Double
	let isDisabled: Bool

	var body: some View {
		VStack(spacing: 12) {
			Text("カラオケスコア")
				.font(.subheadline.bold())
				.frame(maxWidth: .infinity)

			Text(score, format: .number.precision(.fractionLength(1)))
				.font(.system(size: 56, weight: .bold, design: .rounded))
				.monospacedDigit()
				.foregroundStyle(AppColor.accentScore)

			Slider(value: $score, in: 0...100, step: 0.1)
				.disabled(isDisabled)
		}
		.padding()
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
	}
}

#Preview {
	@Previewable @State var score: Double = 92.5
	return RecordingSheetScoreSection(score: $score, isDisabled: false)
		.padding()
}

