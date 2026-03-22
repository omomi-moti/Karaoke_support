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
			/// コンパクト `DatePicker` は内在幅に縮むため、他セクションと同じカード幅になるよう伸ばす。
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding()
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
	}
}

#Preview {
	@Previewable @State var date = Date()
	return RecordingSheetPerformedAtSection(performedAt: $date, isDisabled: false)
		.padding()
}
