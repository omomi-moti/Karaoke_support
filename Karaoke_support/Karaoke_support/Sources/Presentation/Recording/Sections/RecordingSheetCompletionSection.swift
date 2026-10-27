import SwiftUI

/// 記録シートの「歌い切れた？」（#128）。
struct RecordingSheetCompletionSection: View {
	@Binding var isCompleted: Bool
	let isDisabled: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("歌い切れた？")
				.font(.subheadline.bold())

			HStack(spacing: 12) {
				option(title: "歌い切れた", systemImage: "checkmark", value: true)
				option(title: "歌い切れなかった", systemImage: "xmark", value: false)
			}
		}
		.padding()
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
	}

	private func option(title: String, systemImage: String, value: Bool) -> some View {
		let isSelected = isCompleted == value

		return Button {
			isCompleted = value
		} label: {
			HStack(spacing: 6) {
				Image(systemName: systemImage)
					.font(.footnote.weight(.bold))
					.foregroundStyle(isSelected ? AppColor.accentScore : .secondary)
					.accessibilityHidden(true)
				Text(title)
					.font(.footnote.weight(.semibold))
					.lineLimit(1)
					.minimumScaleFactor(0.8)
			}
			.frame(maxWidth: .infinity)
			.padding(.vertical, 14)
			.foregroundStyle(isSelected ? .primary : .secondary)
			.background(
				RoundedRectangle(cornerRadius: 18, style: .continuous)
					.fill(isSelected ? AppColor.accentScore.opacity(0.2) : Color.clear)
			)
			.overlay(
				RoundedRectangle(cornerRadius: 18, style: .continuous)
					.stroke(
						isSelected ? AppColor.accentScore : Color.secondary.opacity(0.3),
						lineWidth: isSelected ? 2 : 1
					)
			)
		}
		.buttonStyle(.plain)
		.disabled(isDisabled)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}
}

#Preview {
	@Previewable @State var isCompleted = true
	RecordingSheetCompletionSection(isCompleted: $isCompleted, isDisabled: false)
		.padding()
}
