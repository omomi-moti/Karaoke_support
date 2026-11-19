import SwiftUI

struct TrackInputSectionView: View {
	@Binding var state: TrackInputState
	let isDisabled: Bool
	/// 開いたときに曲名の欄にカーソルを置くか（#133）。
	var focusesOnAppear = false
	/// 既存の記録の編集中。曲は差し替えられないので、入力欄ではなく読むだけの表示にする。
	var isLockedForEdit = false
	let suggestionState: TrackSuggestionState
	/// 入力が変わってから新しい検索結果が出るまでの間。候補や「候補はありません」を薄く表示し、候補は押せなくする。
	let isSuggestionStale: Bool
	/// 候補をどちらの欄の文字で引いたか。その欄の下に出し、行の並べ方を変える。
	var suggestionField: TrackInputField = .name
	/// 歌手名の欄で、曲の候補の上に出す歌手名だけの候補。
	var artistNameSuggestions: [String] = []
	/// 「前の曲と同じ曲ですか？」で聞く曲。聞かないときは `nil`。
	var artistlessQuestion: TrackSuggestion? = nil
	var artistlessChoice: ArtistlessTrackChoice? = nil
	/// 答えないまま保存しようとした。
	var isArtistlessChoiceMissing = false
	let onSelectSuggestion: (TrackSuggestion) -> Void
	var onSelectArtistName: (String) -> Void = { _ in }
	var onChooseArtistless: (Bool) -> Void = { _ in }

	@FocusState private var focusedField: TrackInputField?

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("曲名")
				.font(.subheadline.bold())

			if isLockedForEdit {
				lockedTrackName
			} else if state.isEditable {
				TextField("曲名", text: $state.manualName)
					.focused($focusedField, equals: .name)
					.task {
						if focusesOnAppear { focusedField = .name }
					}
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled(true)
					.textFieldStyle(.roundedBorder)
					.disabled(isDisabled)
					.onChange(of: state.manualName) { _, _ in
						state.validationMessage = nil
					}

				validationText(state.validationMessage)

				if suggestionField == .name {
					suggestionSection
				}

				Text("歌手名")
					.font(.subheadline.bold())
					.padding(.top, 4)

				TextField("歌手名", text: $state.manualArtistName)
					.focused($focusedField, equals: .artist)
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled(true)
					.textFieldStyle(.roundedBorder)
					.disabled(isDisabled)
					.onChange(of: state.manualArtistName) { _, _ in
						state.artistValidationMessage = nil
					}

				validationText(state.artistValidationMessage)

				if suggestionField == .artist {
					suggestionSection
				}

				if let artistlessQuestion {
					artistlessQuestionCard(artistlessQuestion)
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

			if !state.isEditable || isLockedForEdit {
				validationText(state.validationMessage)
			}
		}
		.padding()
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
	}

	/// 押せない入力欄に見えないよう、枠を付けずに文字だけ出し、変えられないことを添える。
	private var lockedTrackName: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				VStack(alignment: .leading, spacing: 2) {
					Text(state.displayName.isEmpty ? "曲名" : state.displayName)
						.font(.body.weight(.semibold))
					if let artist = state.normalizedManualArtistName {
						Text(artist)
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
				}
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

				if suggestionField == .artist {
					ForEach(artistNameSuggestions, id: \.self) { artistName in
						Button {
							onSelectArtistName(artistName)
							if state.normalizedManualName == nil { focusedField = .name }
						} label: {
							Text(artistName)
								.lineLimit(1)
								.frame(maxWidth: .infinity, alignment: .leading)
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
						.accessibilityLabel("\(artistName)、歌手名だけ入れる")
					}
				}

				ForEach(items) { item in
					Button {
						onSelectSuggestion(item)
						if item.artistName == nil { focusedField = .artist }
					} label: {
						HStack {
							suggestionTitle(item)
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
					.accessibilityLabel(suggestionAccessibilityLabel(item))
				}
			}
			.opacity(isSuggestionStale ? 0.4 : 1)
			.disabled(isSuggestionStale)
			.animation(.easeInOut(duration: 0.15), value: isSuggestionStale)
			.transition(.opacity)
		}
	}

	/// 曲名の欄では「曲名　歌手名」、歌手名の欄では「歌手名　曲名」の順に出す。歌手名は入らない分を省く。
	@ViewBuilder
	private func suggestionTitle(_ item: TrackSuggestion) -> some View {
		let artist = item.artistName ?? "歌手名なし"
		let (first, second) = suggestionField == .name ? (item.name, artist) : (artist, item.name)
		HStack(spacing: 8) {
			Text(first)
				.lineLimit(1)
				.layoutPriority(1)
			Text(second)
				.font(.footnote)
				.foregroundStyle(item.artistName == nil && suggestionField == .name ? .tertiary : .secondary)
				.lineLimit(1)
		}
	}

	private func suggestionAccessibilityLabel(_ item: TrackSuggestion) -> String {
		let artist = item.artistName ?? "歌手名なし"
		let title = suggestionField == .name ? "\(item.name)、\(artist)" : "\(artist)、\(item.name)"
		return "\(title)、\(item.singCount)回歌唱"
	}

	/// 曲名が同じで歌手名のない前からの曲を、今の記録と同じ曲とするかを聞く（ADR 0011）。選んだ後も選び直せるよう、ボタンは残す。
	private func artistlessQuestionCard(_ track: TrackSuggestion) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("前の「\(track.name)」（\(track.singCount)回・歌手名なし）と同じ曲ですか？")
				.font(.footnote)
				.fixedSize(horizontal: false, vertical: true)

			HStack(spacing: 8) {
				choiceButton("同じ曲", isSelected: artistlessChoice == .sameTrack(trackId: track.trackId)) {
					onChooseArtistless(true)
				}
				choiceButton("別の曲", isSelected: artistlessChoice == .differentTrack(trackId: track.trackId)) {
					onChooseArtistless(false)
				}
			}

			if isArtistlessChoiceMissing {
				validationText("「同じ曲」か「別の曲」を選んでください")
			} else if artistlessChoice == .sameTrack(trackId: track.trackId) {
				Text("歌手名を入れると、前の\(track.singCount)回の記録にも付きます")
					.font(.footnote)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.padding(12)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			RoundedRectangle(cornerRadius: 8, style: .continuous)
				.fill(Color.secondary.opacity(0.12))
		)
		.disabled(isDisabled)
	}

	private func choiceButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			Label(title, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
				.font(.subheadline)
				.padding(.vertical, 6)
				.padding(.horizontal, 10)
				.contentShape(Rectangle())
		}
		.buttonStyle(.bordered)
		.tint(isSelected ? AppColor.accentScore : AppColor.textPrimary)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}

	@ViewBuilder
	private func validationText(_ message: String?) -> some View {
		if let message {
			Text(message)
				.font(.footnote)
				.foregroundStyle(.red)
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
		Track(userEnteredName: "Lemon", userEnteredArtistName: "米津玄師", singCount: 12),
		Track(userEnteredName: "Lemon", singCount: 4),
		Track(userEnteredName: "Lemon (Live)", userEnteredArtistName: "米津玄師", singCount: 3),
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

#Preview("歌手名から") {
	@Previewable @State var state = TrackInputState(mode: .manual, manualArtistName: "米津")
	let suggestions = [
		Track(userEnteredName: "Lemon", userEnteredArtistName: "米津玄師", singCount: 12),
		Track(userEnteredName: "馬と鹿", userEnteredArtistName: "米津玄師", singCount: 5),
	].compactMap(TrackSuggestion.init(track:))
	return TrackInputSectionView(
		state: $state,
		isDisabled: false,
		suggestionState: .suggestions(suggestions),
		isSuggestionStale: false,
		suggestionField: .artist,
		artistNameSuggestions: ["米津玄師"],
		onSelectSuggestion: { _ in }
	)
	.padding()
}

#Preview("歌手名なしの前の曲") {
	@Previewable @State var state = TrackInputState(mode: .manual, manualName: "Lemon", manualArtistName: "米津玄師")
	let track = TrackSuggestion(track: Track(userEnteredName: "Lemon", singCount: 12))!
	return TrackInputSectionView(
		state: $state,
		isDisabled: false,
		suggestionState: .hidden,
		isSuggestionStale: false,
		artistlessQuestion: track,
		artistlessChoice: .sameTrack(trackId: track.trackId),
		onSelectSuggestion: { _ in }
	)
	.padding()
}
