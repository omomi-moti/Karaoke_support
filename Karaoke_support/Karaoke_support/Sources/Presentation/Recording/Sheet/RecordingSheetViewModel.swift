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

	static let maxTrackSuggestions = 5

	/// 曲名入力欄の下の「もしかして」欄。
	private(set) var trackSuggestionState: TrackSuggestionState = .hidden

	/// 今出ている候補（または「候補はありません」）を検索したときの入力（前後の空白を除いたもの）。
	private var trackSuggestionQuery: String?

	/// 入力が変わってから新しい検索結果が出るまでの間、今出ている候補や「候補はありません」は前の入力に対する結果なので古い。
	/// 表示は残し（ちらつき防止）、薄くして候補は選べないようにする。
	var isTrackSuggestionStale: Bool {
		switch trackSuggestionState {
		case .hidden:
			return false
		case .noMatch, .suggestions:
			return trackSuggestionQuery != trackState.normalizedManualName
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
		if let intent {
			self.draft.intent = intent
		}
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
			wantAgain: editingSession.wantAgain
		)
		self.pendingSessionIdForSave = nil
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
			var state = TrackInputState(mode: .manual)
			state.manualName = name
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
			let track = try await trackRepository.getOrCreate(
				spotifyTrackId: selectedTrack.spotifyTrackId,
				userEnteredName: selectedTrack.userEnteredName
			)
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
					wantAgain: draft.wantAgain
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
				source: suggestion.flatMap { $0.track == selectedTrack ? $0.source : nil } ?? .manual,
				wantAgain: draft.wantAgain
			)
			try await sessionRepository.saveNewRecordingSession(session)
			pendingSessionIdForSave = nil
			return Self.savedRecording(session, isNewRecording: true)
		} catch {
			inlineErrorMessage = "保存に失敗しました。もう一度お試しください"
			return nil
		}
	}

	private static func savedRecording(_ session: SingingSession, isNewRecording: Bool) -> SavedRecording {
		SavedRecording(
			sessionId: session.id,
			trackId: session.track.id,
			trackTitle: TrackDisplayTitle.primary(for: session.track),
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
			trackSuggestionState = .hidden
			return
		}

		do {
			try await Task.sleep(for: suggestionDebounce)
			let found = try await trackRepository.searchLocal(query: trimmed)
			try Task.checkCancellation()
			// キャンセルが届く前に入力が置き換わった（候補をタップした等）なら古い結果は捨てる
			guard canShowTrackSuggestions, trackState.normalizedManualName == trimmed else { return }

			// 既存の曲名と完全一致なら、そのまま保存すれば既存の曲につながるので出さない。
			// getOrCreate と同じ条件（Spotify ID なし・曲名が完全一致）で、歌唱回数 0 の曲も含めて判定する
			if found.contains(where: { $0.spotifyTrackId == nil && $0.userEnteredName == trimmed }) {
				trackSuggestionState = .hidden
				return
			}

			// 記録を全部消した曲（打ち間違いで作った曲など）は Track だけ残るので候補から除く。
			// 前方一致の曲が回数順で 6 件目以降にあっても上位に入るよう、件数を絞る前に並べ替える
			let candidates = TrackSuggestionRanker
				.rank(found.filter { $0.singCount > 0 }, query: trimmed)
				.compactMap(TrackSuggestion.init(track:))
			trackSuggestionQuery = trimmed
			if candidates.isEmpty {
				trackSuggestionState = .noMatch
			} else {
				trackSuggestionState = .suggestions(Array(candidates.prefix(Self.maxTrackSuggestions)))
			}
		} catch is CancellationError {
			return
		} catch {
			// 成功時と同じく、入力が置き換わった後の古い検索のエラーで今の表示を上書きしない
			guard !Task.isCancelled, canShowTrackSuggestions, trackState.normalizedManualName == trimmed else { return }
			// 補助機能なので入力は妨げない。「候補なし」とは区別して何も出さない
			trackSuggestionState = .hidden
		}
	}

	func applyTrackSuggestion(_ suggestion: TrackSuggestion) {
		// View で押せなくしているが、前の入力に対する候補で入力欄を書き換えないよう ViewModel でも弾く
		guard !isTrackSuggestionStale else { return }
		trackSuggestionState = .hidden
		trackState.manualName = suggestion.name
	}
}
