import SwiftUI

struct TrackInputSectionView: View {
	@Binding var state: TrackInputState
	let isDisabled: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("曲名")
				.font(.subheadline.bold())

			if state.isEditable {
				TextField("曲名", text: $state.manualName)
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled(true)
					.textFieldStyle(.roundedBorder)
					.disabled(isDisabled)
					.onChange(of: state.manualName) { _, _ in
						state.validationMessage = nil
					}
			} else {
				Text(state.displayName.isEmpty ? "曲名" : state.displayName)
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding(.vertical, 10)
					.padding(.horizontal, 12)
					.background(
						RoundedRectangle(cornerRadius: 8, style: .continuous)
							.fill(Color.secondary.opacity(0.12))
					)
					.overlay(
						RoundedRectangle(cornerRadius: 8, style: .continuous)
							.stroke(Color.secondary.opacity(0.25), lineWidth: 1)
					)
			}

			if let msg = state.validationMessage {
				Text(msg)
					.font(.footnote)
					.foregroundStyle(.red)
			}
		}
		.padding()
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
	}
}

#Preview {
	@Previewable @State var state = TrackInputState(mode: .manual)
	return TrackInputSectionView(state: $state, isDisabled: false)
		.padding()
}

