import SwiftUI

struct RecordingSheetMemoSection: View {
	@Binding var memo: String

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("メモ（オプション）")
				.font(.subheadline.bold())

			TextField("メモ（オプション）", text: $memo, axis: .vertical)
				.lineLimit(3...6)
				.textFieldStyle(.roundedBorder)
		}
		.padding()
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
	}
}

#Preview {
	@Previewable @State var memo: String = ""
	return RecordingSheetMemoSection(memo: $memo)
		.padding()
}

