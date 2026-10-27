import SwiftUI

struct RecordingSheetMemoSection: View {
	@Binding var memo: String
	var placeholder = "ひとこと"
	let isDisabled: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("メモ")
				.font(.subheadline.bold())

			ZStack(alignment: .topLeading) {
				if memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
					Text(placeholder)
						.foregroundStyle(.tertiary)
						.padding(.top, 10)
						.padding(.horizontal, 12)
						.allowsHitTesting(false)
				}

				TextEditor(text: $memo)
					.disabled(isDisabled)
					.scrollContentBackground(.hidden)
					.frame(minHeight: 80, maxHeight: 120)
					.padding(4)
			}
		}
		.padding()
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
	}
}

#Preview {
	@Previewable @State var memo: String = ""
	return RecordingSheetMemoSection(memo: $memo, isDisabled: false)
		.padding()
}

