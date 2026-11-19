import Foundation
import Observation

@MainActor
@Observable
final class RecordingSheetViewModel {
	var trackState: TrackInputState
	var draft: RecordingDraft = .init()

	var isSaving: Bool = false
	var inlineErrorMessage: String? = nil

	/// `nil` のとき新規記録、非 `nil` のときその id のセッションを更新（I-014-C）。
	private(set) var editingSessionId: UUID?

	/// 編集している記録の、編集を始める前の歌唱日時（編集中の帯に出す）。新規記録では `nil`。
	private(set) var editingSessionOriginalPerformedAt: Date?

	private let sessionRepository: any SessionRepositoryProtocol
	private let trackRepository: any TrackRepositoryProtocol

	/// 提案や選曲画面のカードから開いたときの曲と入口。保存するときにこの曲のままなら、記録の入口をこの `source` にする（#120・#126）。
	private let suggestion: (track: SelectedTrack, source: RecordSource)?

	/// 保存失敗後の再試行で同一 ``SingingSession.id`` を使う（I-011 Idempotency Key）。成功時は `nil` に戻す。**新規のみ**使用。
	private var pendingSessionIdForSave: UUID?

	var isEditingExistingSession: Bool { editingSessionId != nil }

	var isTrackInputLockedForEdit: Bool { editingSessionId != nil }

	/// 開いたときの入力。閉じるときに、入力が変わったかを見るために覚えておく（#133）。
	@ObservationIgnored private var initialDraft = RecordingDraft()
	@ObservationIgnored private var initialManualName = ""
	@ObservationIgnored private var initialManualArtistName = ""

	/// 開いたときから入力が変わったか。変わっていれば、閉じる前に確認する（#133）。
	var hasUnsavedChanges: Bool {
		draft != initialDraft
			|| trackState.manualName != initialManualName
			|| trackState.manualArtistName != initialManualArtistName
	}

	/// 開いたときに曲名の欄にカーソルを置くか。＋で空のシートを開いたときだけ置く（#133）。
	private(set) var focusesTrackNameOnOpen = false

	/// メモの案内。歌い切れなかったときは、難しかったところを書いてもらう（#128）。
	var memoPlaceholder: String { draft.isCompleted ? "ひとこと" : "どこが難しかった？" }

	static let maxTrackSuggestions = 5

	/// 曲名入力欄の下の「もしかして」欄。
	private(set) var trackSuggestionState: TrackSuggestionState = .hidden

	/// 今出ている候補（または「候補はありません」）を検索したときの入力（前後の空白を除いたもの）。
	private var trackSuggestionQuery: String?

	/// 今出ている候補を、どちらの欄の文字で引いたか。最後に打った欄の候補を出す。
	private(set) var trackSuggestionField: TrackInputField = .name

	/// 歌手名の欄で、曲の候補の上に出す歌手名だけの候補。押すと歌手名だけが入る（初めて歌う曲でも選べるように）。
	private(set) var artistNameSuggestions: [String] = []

	/// 歌手名だけの候補で選んだ歌手名。歌手名の欄がこのままの間は、候補を出し直さない。
	private var pickedArtistName: String?

	static let maxArtistNameSuggestions = 3

	/// 曲名が今の入力と完全に同じで、歌手名のない前からの曲（歌唱回数 1 回以上）。今の記録と同じ曲かを聞くために使う（ADR 0011）。
	private var artistlessSameNameTrack: TrackSuggestion?
	/// ``artistlessSameNameTrack`` と ``sameNameTrackArtists`` を探したときの曲名。
	private var sameNameLookupName: String?
	/// 曲名が今の入力と完全に同じ曲の歌手名（歌手名のない曲は `nil`）。曲名と歌手名の両方が同じ曲があれば、聞かずにその曲につなぐ。
	private var sameNameTrackArtists: [String?] = []

	/// 歌手名のない前からの曲について、本人が選んだ答え。
	private(set) var artistlessTrackChoice: ArtistlessTrackChoice?

	/// 答えないまま保存しようとした。答えるまで「同じ曲ですか？」のカードにそう出す。
	private(set) var isArtistlessTrackChoiceMissing = false

	/// 選曲・曲詳細・提案から歌手名のない曲で開いたときの曲名。この曲名の歌手名なしの曲は、初めから「同じ曲」を選んだ状態にする。
	private var presetSameTrackName: String?

	/// 「前の曲と同じ曲ですか？」で聞く曲。聞かないときは `nil`。
	///
	/// 曲名が同じで歌手名のない曲があり、曲名と歌手名の両方が同じ曲はないときに聞く。
	var artistlessTrackQuestion: TrackSuggestion? {
		guard canShowTrackSuggestions,
		      let track = artistlessSameNameTrack,
		      sameNameLookupName == trackState.normalizedManualName else { return nil }
		if let artist = trackState.normalizedManualArtistName, sameNameTrackArtists.contains(artist) {
			return nil
		}
		return track
	}

	/// ``artistlessTrackQuestion`` の曲についての答え。答えていない、または別の曲についての答えなら `nil`。
	var currentArtistlessTrackChoice: ArtistlessTrackChoice? {
		guard let question = artistlessTrackQuestion, artistlessTrackChoice?.trackId == question.trackId else { return nil }
		return artistlessTrackChoice
	}

	/// 入力が変わってから新しい検索結果が出るまでの間、今出ている候補や「候補はありません」は前の入力に対する結果なので古い。
	/// 表示は残し（ちらつき防止）、薄くして候補は選べないようにする。
	var isTrackSuggestionStale: Bool {
		switch trackSuggestionState {
		case .hidden:
			return false
		case .noMatch, .suggestions:
			let current = trackSuggestionField == .name ? trackState.normalizedManualName : trackState.normalizedManualArtistName
			return trackSuggestionQuery != current
		}
	}

	/// 入力が止まってから検索するまでの待ち時間。テストでは `.zero` にする。
	@ObservationIgnored var suggestionDebounce: Duration = .milliseconds(300)

	/// 新規記録の歌唱日時に使う現在時刻。テストでは固定の時刻を返す。
	@ObservationIgnored var now: () -> Date = Date.init

	private var canShowTrackSuggestions: Bool {
		trackState.isEditable && !isTrackInputLockedForEdit
	}

	init(
		trackMode: TrackInputMode,
		sessionRepository: any SessionRepositoryProtocol,
		trackRepository: any TrackRepositoryProtocol
	) {
		self.editingSessionId = nil
		self.suggestion = nil
		self.trackState = TrackInputState(mode: trackMode)
		self.sessionRepository = sessionRepository
		self.trackRepository = trackRepository
		self.focusesTrackNameOnOpen = trackState.isEditable && trackState.manualName.isEmpty
		rememberInitialInput()
	}

	/// 確定済み ``SelectedTrack`` から開始（ランキング・検索など I-013）。`intent` を渡すと気分を選んだ状態にする。
	/// `source` が `.manual` 以外のときは、曲を変えずに保存すると、その入口からの記録になる（#120・#126）。
	init(
		selectedTrack: SelectedTrack,
		intent: Intent? = nil,
		source: RecordSource = .manual,
		sessionRepository: any SessionRepositoryProtocol,
		trackRepository: any TrackRepositoryProtocol
	) {
		self.editingSessionId = nil
		self.sessionRepository = sessionRepository
		self.trackRepository = trackRepository
		let built = Self.trackInputState(from: selectedTrack)
		self.trackState = built.state
		// 保存するときと同じ形（前後の空白を除いた曲名・Spotify ID）で覚えておき、そのまま比べられるようにする
		self.suggestion = source == .manual
			? nil
			: (try? TrackResolver.resolveSelectedTrack(from: built.state)).map { (track: $0, source: source) }
		self.inlineErrorMessage = built.initialInlineError
		if selectedTrack.spotifyTrackId == nil, selectedTrack.userEnteredArtistName == nil {
			self.presetSameTrackName = selectedTrack.userEnteredName
		}
		if let intent {
			self.draft.intent = intent
		}
		rememberInitialInput()
	}

	/// 履歴から開いた既存セッションの編集（I-014-C）。曲の差し替えは不可。
	init(
		editingSession: SingingSession,
		sessionRepository: any SessionRepositoryProtocol,
		trackRepository: any TrackRepositoryProtocol
	) {
		self.editingSessionId = editingSession.id
		self.editingSessionOriginalPerformedAt = editingSession.performedAt
		self.suggestion = nil
		self.sessionRepository = sessionRepository
		self.trackRepository = trackRepository
		self.trackState = TrackInputState(trackForEditingSession: editingSession.track)
		self.draft = RecordingDraft(
			score: editingSession.score.map(ScoreDigitInput.init(score:)) ?? ScoreDigitInput(),
			intent: editingSession.intent,
			memo: editingSession.memo ?? "",
			performedAt: editingSession.performedAt,
			wantAgain: editingSession.wantAgain,
			isCompleted: editingSession.isCompleted
		)
		self.pendingSessionIdForSave = nil
		rememberInitialInput()
	}

	private func rememberInitialInput() {
		initialDraft = draft
		initialManualName = trackState.manualName
		initialManualArtistName = trackState.manualArtistName
	}

	/// ``SelectedTrack`` の failable `init?` 経由では `(nil, nil)` は起こらないが、将来の生成経路で不変条件が崩れた場合に備え本番では落とさない。
	private static func trackInputState(from selected: SelectedTrack) -> (state: TrackInputState, initialInlineError: String?) {
		switch (selected.spotifyTrackId, selected.userEnteredName) {
		case let (spotify?, nil):
			return (
				TrackInputState(
					mode: .spotifyHistory(spotifyTrackId: spotify, displayName: Self.fallbackDisplayName(forSpotifyId: spotify))
				),
				nil
			)
		case let (nil, name?):
			let state = TrackInputState(mode: .manual, manualName: name, manualArtistName: selected.userEnteredArtistName ?? "")
			return (state, nil)
		case let (spotify?, name?):
			return (
				TrackInputState(
					mode: .spotifyHistory(spotifyTrackId: spotify, displayName: name)
				),
				nil
			)
		case (nil, nil):
			assertionFailure("SelectedTrack invariant violated: both spotifyTrackId and userEnteredName are nil")
			return (TrackInputState(mode: .manual), "曲の情報が無効です。選び直してください")
		}
	}

	/// V2 の TrackMetadata まで表示名は置き換え。
	private static func fallbackDisplayName(forSpotifyId id: String) -> String {
		if id.count > 12 {
			return String(id.prefix(12)) + "…"
		}
		return id
	}

	func validate() -> Bool {
		inlineErrorMessage = nil
		trackState.artistValidationMessage = nil
		do {
			_ = try TrackResolver.resolveSelectedTrack(from: trackState)
			return true
		} catch let error as TrackResolveError {
			switch error {
			case .emptyManualName:
				if case .manual = trackState.mode {
					trackState.validationMessage = "曲名を入力してください"
				}
			case .invalidSelectedTrack:
				inlineErrorMessage = "曲の情報が無効です。選び直してください"
			}
			return false
		} catch {
			inlineErrorMessage = "予期しないエラーが発生しました。もう一度お試しください"
			return false
		}
	}

	/// 新規は ``saveNewRecordingSession``、編集は ``updateRecordingSession``（I-014-C / I-003）。
	/// - Returns: 保存した記録の要約。保存しなかった・失敗したときは `nil`。
	///   成否と要約を 1 つの値で返し、「成功したのに要約がない」状態を作れないようにしている（ADR 0028）。
	func save() async -> SavedRecording? {
		guard !isSaving else { return nil }
		guard validate() else { return nil }

		isSaving = true
		defer { isSaving = false }

		do {
			let selectedTrack = try TrackResolver.resolveSelectedTrack(from: trackState)
			let track: Track
			if editingSessionId == nil, case .manual = trackState.mode, let name = selectedTrack.userEnteredName {
				guard let resolved = try await resolveNewManualTrack(name: name, artist: selectedTrack.userEnteredArtistName) else {
					return nil
				}
				track = resolved
			} else {
				track = try await trackRepository.getOrCreate(
					spotifyTrackId: selectedTrack.spotifyTrackId,
					userEnteredName: selectedTrack.userEnteredName,
					userEnteredArtistName: selectedTrack.userEnteredArtistName
				)
			}
			// 点数の入力は任意。未入力なら nil で保存する
			let score = draft.score.value

			if let editId = editingSessionId {
				let session = SingingSession(
					id: editId,
					track: track,
					intent: draft.intent,
					performedAt: draft.performedAt,
					score: score,
					memo: draft.normalizedMemo,
					wantAgain: draft.wantAgain,
					isCompleted: draft.isCompleted
				)
				try await sessionRepository.updateRecordingSession(session)
				return Self.savedRecording(session, isNewRecording: false)
			}

			let sessionId: UUID
			if let pending = pendingSessionIdForSave {
				sessionId = pending
			} else {
				let newId = UUID()
				pendingSessionIdForSave = newId
				sessionId = newId
			}
			let session = SingingSession(
				id: sessionId,
				track: track,
				intent: draft.intent,
				// 新規記録は日時欄を出さないので、保存した時刻を歌唱日時にする
				performedAt: now(),
				score: score,
				memo: draft.normalizedMemo,
				// 提案や選曲画面のカードから開いても、曲を書き換えたら自分で選んだ記録として数える
				source: suggestion.flatMap { Self.isSameTrack($0.track, savedAs: selectedTrack) ? $0.source : nil } ?? .manual,
				wantAgain: draft.wantAgain,
				isCompleted: draft.isCompleted
			)
			try await sessionRepository.saveNewRecordingSession(session)
			pendingSessionIdForSave = nil
			return Self.savedRecording(session, isNewRecording: true)
		} catch {
			inlineErrorMessage = "保存に失敗しました。もう一度お試しください"
			return nil
		}
	}

	/// 新しい記録の手入力の曲を決める。歌手名か「同じ曲か」の答えが足りなければ、入力欄にそう出して `nil` を返す。
	///
	/// - 曲名と歌手名の両方が同じ曲（歌手名が空どうしも含む）があれば、その曲
	/// - 歌手名が空なら、新しい曲は作らない（歌手名を必須にする）
	/// - 曲名が同じで歌手名のない曲があれば、本人の答えに従う（同じ曲なら歌手名を書き足す・別の曲なら新しく作る）
	/// - どれでもなければ新しく作る
	private func resolveNewManualTrack(name: String, artist: String?) async throws -> Track? {
		let found = try await trackRepository.searchLocal(query: name)
		let sameName = found.filter { $0.spotifyTrackId == nil && $0.userEnteredName == name }
		if sameName.contains(where: { TrackDisplayTitle.artist(for: $0) == artist }) {
			return try await trackRepository.getOrCreate(spotifyTrackId: nil, userEnteredName: name, userEnteredArtistName: artist)
		}
		guard let artist else {
			trackState.artistValidationMessage = "歌手名を入力してください"
			return nil
		}
		rememberSameNameTracks(sameName, name: name)
		if let question = artistlessTrackQuestion {
			switch currentArtistlessTrackChoice {
			case .sameTrack:
				return try await trackRepository.fillArtistName(artist, trackId: question.trackId)
			case .differentTrack:
				break
			case nil:
				isArtistlessTrackChoiceMissing = true
				return nil
			}
		}
		return try await trackRepository.getOrCreate(spotifyTrackId: nil, userEnteredName: name, userEnteredArtistName: artist)
	}

	/// 開いたときの曲から変えずに保存したか。歌手名のない曲で開いたときは、歌手名を足して保存しても同じ曲とみなす。
	private static func isSameTrack(_ opened: SelectedTrack, savedAs saved: SelectedTrack) -> Bool {
		opened.spotifyTrackId == saved.spotifyTrackId
			&& opened.userEnteredName == saved.userEnteredName
			&& (opened.userEnteredArtistName == nil || opened.userEnteredArtistName == saved.userEnteredArtistName)
	}

	private static func savedRecording(_ session: SingingSession, isNewRecording: Bool) -> SavedRecording {
		SavedRecording(
			sessionId: session.id,
			trackId: session.track.id,
			trackTitle: TrackDisplayTitle.primary(for: session.track),
			trackArtistName: TrackDisplayTitle.artist(for: session.track),
			intent: session.intent,
			score: session.score,
			isNewRecording: isNewRecording
		)
	}

	// MARK: - 曲名サジェスト（もしかして）

	/// 入力中の曲名から、歌ったことがある曲を「もしかして」として探す。
	func updateTrackSuggestions(for query: String) async {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard canShowTrackSuggestions, !trimmed.isEmpty else {
			if trackSuggestionField == .name { trackSuggestionState = .hidden }
			return
		}
		trackSuggestionField = .name

		do {
			try await Task.sleep(for: suggestionDebounce)
			let found = try await trackRepository.searchLocal(query: trimmed)
			try Task.checkCancellation()
			// キャンセルが届く前に入力が置き換わった（候補をタップした等）なら古い結果は捨てる
			guard canShowTrackSuggestions, trackState.normalizedManualName == trimmed else { return }

			// getOrCreate と同じ条件（Spotify ID なし・曲名が完全一致）で、歌唱回数 0 の曲も含めて探す
			let sameName = found.filter { $0.spotifyTrackId == nil && $0.userEnteredName == trimmed }
			rememberSameNameTracks(sameName, name: trimmed)
			guard trackSuggestionField == .name else { return }

			// 曲名と歌手名の両方が同じ曲があれば、そのまま保存すれば既存の曲につながるので出さない
			let artist = trackState.normalizedManualArtistName
			if let artist, sameName.contains(where: { TrackDisplayTitle.artist(for: $0) == artist }) {
				trackSuggestionState = .hidden
				return
			}

			// 記録を全部消した曲（打ち間違いで作った曲など）は Track だけ残るので候補から除く。
			// 前方一致の曲が回数順で 6 件目以降にあっても上位に入るよう、件数を絞る前に並べ替える
			let ranked = TrackSuggestionRanker
				.rank(
					found.filter { $0.singCount > 0 && !($0.userEnteredName == trimmed && TrackDisplayTitle.artist(for: $0) == nil) },
					query: trimmed
				)
				.compactMap(TrackSuggestion.init(track:))
			let candidates: [TrackSuggestion]
			if let artist {
				let isByArtist = { (item: TrackSuggestion) in item.artistName?.localizedStandardContains(artist) ?? false }
				candidates = ranked.filter(isByArtist) + ranked.filter { !isByArtist($0) }
			} else {
				candidates = ranked
			}
			trackSuggestionQuery = trimmed
			if !candidates.isEmpty {
				trackSuggestionState = .suggestions(Array(candidates.prefix(Self.maxTrackSuggestions)))
			} else if sameName.isEmpty {
				trackSuggestionState = .noMatch
			} else {
				trackSuggestionState = .hidden
			}
		} catch is CancellationError {
			return
		} catch {
			// 成功時と同じく、入力が置き換わった後の古い検索のエラーで今の表示を上書きしない
			guard !Task.isCancelled, canShowTrackSuggestions, trackState.normalizedManualName == trimmed,
			      trackSuggestionField == .name else { return }
			// 補助機能なので入力は妨げない。「候補なし」とは区別して何も出さない
			trackSuggestionState = .hidden
		}
	}

	/// 入力中の歌手名から、その歌手の歌ったことがある曲を「もしかして」として探す。
	func updateArtistSuggestions(for query: String) async {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard canShowTrackSuggestions, !trimmed.isEmpty else {
			if trackSuggestionField == .artist { trackSuggestionState = .hidden }
			return
		}
		trackSuggestionField = .artist
		if trimmed == pickedArtistName {
			trackSuggestionState = .hidden
			return
		}

		do {
			try await Task.sleep(for: suggestionDebounce)
			let found = try await trackRepository.searchLocalByArtist(query: trimmed)
			try Task.checkCancellation()
			guard canShowTrackSuggestions, trackState.normalizedManualArtistName == trimmed,
			      trackSuggestionField == .artist else { return }

			let name = trackState.normalizedManualName
			if let name, found.contains(where: {
				$0.spotifyTrackId == nil && $0.userEnteredName == name && TrackDisplayTitle.artist(for: $0) == trimmed
			}) {
				trackSuggestionState = .hidden
				return
			}

			let candidates = TrackSuggestionRanker
				.rank(found.filter { $0.singCount > 0 }, query: trimmed, matchedText: \.userEnteredArtistName)
				.compactMap(TrackSuggestion.init(track:))
			var artistNames: [String] = []
			for artist in candidates.compactMap(\.artistName) where artist != trimmed && !artistNames.contains(artist) {
				artistNames.append(artist)
			}
			artistNameSuggestions = Array(artistNames.prefix(Self.maxArtistNameSuggestions))
			trackSuggestionQuery = trimmed
			trackSuggestionState = candidates.isEmpty
				? .noMatch
				: .suggestions(Array(candidates.prefix(Self.maxTrackSuggestions)))
		} catch is CancellationError {
			return
		} catch {
			guard !Task.isCancelled, canShowTrackSuggestions, trackState.normalizedManualArtistName == trimmed,
			      trackSuggestionField == .artist else { return }
			trackSuggestionState = .hidden
		}
	}

	/// 候補の曲名と歌手名を両方の欄に入れる。歌手名のない曲なら、その曲と同じ曲として記録する。
	func applyTrackSuggestion(_ suggestion: TrackSuggestion) {
		// View で押せなくしているが、前の入力に対する候補で入力欄を書き換えないよう ViewModel でも弾く
		guard !isTrackSuggestionStale else { return }
		trackSuggestionState = .hidden
		trackState.manualName = suggestion.name
		trackState.manualArtistName = suggestion.artistName ?? ""
		if suggestion.artistName == nil {
			artistlessSameNameTrack = suggestion
			sameNameLookupName = suggestion.name
			sameNameTrackArtists = [nil]
			artistlessTrackChoice = .sameTrack(trackId: suggestion.trackId)
		}
	}

	/// 歌手名だけの候補を歌手名の欄に入れる。曲名の欄はそのままにする。
	func applyArtistNameSuggestion(_ artistName: String) {
		guard !isTrackSuggestionStale else { return }
		trackSuggestionState = .hidden
		pickedArtistName = artistName
		trackState.manualArtistName = artistName
	}

	/// 「前の曲と同じ曲ですか？」に答える。
	func chooseArtistlessTrack(isSameTrack: Bool) {
		guard let question = artistlessTrackQuestion else { return }
		artistlessTrackChoice = isSameTrack
			? .sameTrack(trackId: question.trackId)
			: .differentTrack(trackId: question.trackId)
		isArtistlessTrackChoiceMissing = false
	}

	/// 曲名が完全に同じ曲を覚えておく。歌手名のない曲で開いた曲名なら、その曲を「同じ曲」に選んでおく。
	private func rememberSameNameTracks(_ sameName: [Track], name: String) {
		sameNameLookupName = name
		sameNameTrackArtists = sameName.map { TrackDisplayTitle.artist(for: $0) }
		artistlessSameNameTrack = sameName
			.first { TrackDisplayTitle.artist(for: $0) == nil && $0.singCount > 0 }
			.flatMap(TrackSuggestion.init(track:))
		if let track = artistlessSameNameTrack, name == presetSameTrackName, artistlessTrackChoice?.trackId != track.trackId {
			artistlessTrackChoice = .sameTrack(trackId: track.trackId)
		}
	}
}
