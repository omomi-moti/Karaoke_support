import SwiftUI

/// 歌唱日時（``RecordingDraft/performedAt``）。
struct RecordingSheetPerformedAtSection: View {
	@Binding var performedAt: Date
	let isDisabled: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("歌唱日時")
				.font(.subheadline.bold())

			DatePicker(
				"歌唱日時",
				selection: $performedAt,
				displayedComponents: [.date, .hourAndMinute]
			)
			.labelsHidden()
			.disabled(isDisabled)
		}
		.padding()
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
	}
}

#Preview {
	@Previewable @State var date = Date()
	return RecordingSheetPerformedAtSection(performedAt: $date, isDisabled: false)
		.padding()
}
