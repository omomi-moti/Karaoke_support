import SwiftUI

struct RecordingSheetIntentSection: View {
	@Binding var intent: Intent
	let isDisabled: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("今日の気分は？")
				.font(.subheadline.bold())

			HStack(spacing: 12) {
				intentButton(.shout, title: "Shout", systemImage: "flame.fill")
				intentButton(.emo, title: "Emo", systemImage: "moon.fill")
				intentButton(.practice, title: "Practice", systemImage: "mic.fill")
			}
		}
		.padding()
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
	}

	private func intentButton(_ value: Intent, title: String, systemImage: String) -> some View {
		let isSelected = intent == value

		return Button {
			intent = value
		} label: {
			VStack(spacing: 10) {
				Image(systemName: systemImage)
					.font(.title3.weight(.semibold))
				Text(title)
					.font(.footnote.weight(.semibold))
			}
			.frame(maxWidth: .infinity)
			.padding(.vertical, 14)
			.foregroundStyle(isSelected ? .primary : .secondary)
			.background(
				RoundedRectangle(cornerRadius: 18, style: .continuous)
					.fill(isSelected ? Color.pink.opacity(0.25) : Color.clear)
			)
			.overlay(
				RoundedRectangle(cornerRadius: 18, style: .continuous)
					.stroke(
						isSelected ? Color.pink : Color.secondary.opacity(0.3),
						lineWidth: isSelected ? 2 : 1
					)
			)
		}
		.buttonStyle(.plain)
		.disabled(isDisabled)
	}
}

#Preview {
	@Previewable @State var intent: Intent = .shout
	return RecordingSheetIntentSection(intent: $intent, isDisabled: false)
		.padding()
}

