import SwiftUI

struct TrackInputSectionView: View {
	@Binding var state: TrackInputState
	let isDisabled: Bool
	/// 既存の記録の編集中。曲は差し替えられないので、入力欄ではなく読むだけの表示にする。
	var isLockedForEdit = false
	let suggestionState: TrackSuggestionState
	/// 入力が変わってから新しい検索結果が出るまでの間。候補や「候補はありません」を薄く表示し、候補は押せなくする。
	let isSuggestionStale: Bool
	let onSelectSuggestion: (TrackSuggestion) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("曲名")
				.font(.subheadline.bold())

			if isLockedForEdit {
				lockedTrackName
			} else if state.isEditable {
				TextField("曲名", text: $state.manualName)
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled(true)
					.textFieldStyle(.roundedBorder)
					.disabled(isDisabled)
					.onChange(of: state.manualName) { _, _ in
						state.validationMessage = nil
					}

				suggestionSection
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

	/// 押せない入力欄に見えないよう、枠を付けずに文字だけ出し、変えられないことを添える。
	private var lockedTrackName: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				Text(state.displayName.isEmpty ? "曲名" : state.displayName)
					.font(.body.weight(.semibold))
				Spacer()
				Image(systemName: "lock.fill")
					.foregroundStyle(.secondary)
					.accessibilityHidden(true)
			}
			Text("曲は変更できません")
				.font(.footnote)
				.foregroundStyle(.secondary)
		}
		.accessibilityElement(children: .combine)
	}

	@ViewBuilder
	private var suggestionSection: some View {
		switch suggestionState {
		case .hidden:
			EmptyView()
		case .noMatch:
			Text("候補はありません")
				.font(.footnote)
				.foregroundStyle(.secondary)
				.opacity(isSuggestionStale ? 0.4 : 1)
				.animation(.easeInOut(duration: 0.15), value: isSuggestionStale)
				.transition(.opacity)
		case .suggestions(let items):
			VStack(alignment: .leading, spacing: 4) {
				Text("もしかして")
					.font(.footnote)
					.foregroundStyle(.secondary)

				ForEach(items) { item in
					Button {
						onSelectSuggestion(item)
					} label: {
						HStack {
							Text(item.name)
								.lineLimit(1)
							Spacer()
							Text("\(item.singCount)回歌唱")
								.font(.footnote)
								.foregroundStyle(.secondary)
						}
						.padding(.vertical, 8)
						.padding(.horizontal, 12)
						.contentShape(Rectangle())
					}
					.buttonStyle(.plain)
					.background(
						RoundedRectangle(cornerRadius: 8, style: .continuous)
							.fill(Color.secondary.opacity(0.12))
					)
					.disabled(isDisabled)
					.accessibilityLabel("\(item.name)、\(item.singCount)回歌唱")
				}
			}
			.opacity(isSuggestionStale ? 0.4 : 1)
			.disabled(isSuggestionStale)
			.animation(.easeInOut(duration: 0.15), value: isSuggestionStale)
			.transition(.opacity)
		}
	}
}

#Preview {
	@Previewable @State var state = TrackInputState(mode: .manual)
	return TrackInputSectionView(
		state: $state,
		isDisabled: false,
		suggestionState: .hidden,
		isSuggestionStale: false,
		onSelectSuggestion: { _ in }
	)
	.padding()
}

#Preview("もしかして") {
	@Previewable @State var state = TrackInputState(mode: .manual, manualName: "lemon")
	let suggestions = [
		Track(userEnteredName: "Lemon", singCount: 12),
		Track(userEnteredName: "Lemon (Live)", singCount: 3),
	].compactMap(TrackSuggestion.init(track:))
	return TrackInputSectionView(
		state: $state,
		isDisabled: false,
		suggestionState: .suggestions(suggestions),
		isSuggestionStale: false,
		onSelectSuggestion: { state.manualName = $0.name }
	)
	.padding()
}

#Preview("もしかして（入力が変わった直後）") {
	@Previewable @State var state = TrackInputState(mode: .manual, manualName: "lemonx")
	let suggestions = [Track(userEnteredName: "Lemon", singCount: 12)].compactMap(TrackSuggestion.init(track:))
	return TrackInputSectionView(
		state: $state,
		isDisabled: false,
		suggestionState: .suggestions(suggestions),
		isSuggestionStale: true,
		onSelectSuggestion: { _ in }
	)
	.padding()
}

#Preview("候補はありません") {
	@Previewable @State var state = TrackInputState(mode: .manual, manualName: "まりーごーるど")
	return TrackInputSectionView(
		state: $state,
		isDisabled: false,
		suggestionState: .noMatch,
		isSuggestionStale: false,
		onSelectSuggestion: { _ in }
	)
	.padding()
}

