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

	private let sessionRepository: any SessionRepositoryProtocol
	private let trackRepository: any TrackRepositoryProtocol

	/// 保存失敗後の再試行で同一 ``SingingSession.id`` を使う（I-011 Idempotency Key）。成功時は `nil` に戻す。**新規のみ**使用。
	private var pendingSessionIdForSave: UUID?

	var isEditingExistingSession: Bool { editingSessionId != nil }

	var isTrackInputLockedForEdit: Bool { editingSessionId != nil }

	static let maxTrackSuggestions = 5

	/// 曲名入力欄の下の「もしかして」欄。
	private(set) var trackSuggestionState: TrackSuggestionState = .hidden

	/// 入力が止まってから検索するまでの待ち時間。テストでは `.zero` にする。
	@ObservationIgnored var suggestionDebounce: Duration = .milliseconds(300)

	private var canShowTrackSuggestions: Bool {
		trackState.isEditable && !isTrackInputLockedForEdit
	}

	init(
		trackMode: TrackInputMode,
		sessionRepository: any SessionRepositoryProtocol,
		trackRepository: any TrackRepositoryProtocol
	) {
		self.editingSessionId = nil
		self.trackState = TrackInputState(mode: trackMode)
		self.sessionRepository = sessionRepository
		self.trackRepository = trackRepository
	}

	/// 確定済み ``SelectedTrack`` から開始（ランキング・検索など I-013）。
	init(
		selectedTrack: SelectedTrack,
		sessionRepository: any SessionRepositoryProtocol,
		trackRepository: any TrackRepositoryProtocol
	) {
		self.editingSessionId = nil
		self.sessionRepository = sessionRepository
		self.trackRepository = trackRepository
		let built = Self.trackInputState(from: selectedTrack)
		self.trackState = built.state
		self.inlineErrorMessage = built.initialInlineError
	}

	/// 履歴から開いた既存セッションの編集（I-014-C）。曲の差し替えは不可。
	init(
		editingSession: SingingSession,
		sessionRepository: any SessionRepositoryProtocol,
		trackRepository: any TrackRepositoryProtocol
	) {
		self.editingSessionId = editingSession.id
		self.sessionRepository = sessionRepository
		self.trackRepository = trackRepository
		self.trackState = TrackInputState(trackForEditingSession: editingSession.track)
		self.draft = RecordingDraft(
			score: editingSession.score,
			intent: editingSession.intent,
			memo: editingSession.memo ?? "",
			performedAt: editingSession.performedAt
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
	func save() async -> Bool {
		guard !isSaving else { return false }
		guard validate() else { return false }

		isSaving = true
		defer { isSaving = false }

		do {
			let selectedTrack = try TrackResolver.resolveSelectedTrack(from: trackState)
			let track = try await trackRepository.getOrCreate(
				spotifyTrackId: selectedTrack.spotifyTrackId,
				userEnteredName: selectedTrack.userEnteredName
			)
			let score = Self.normalizedScoreForPersistence(draft.score)

			if let editId = editingSessionId {
				let session = SingingSession(
					id: editId,
					track: track,
					intent: draft.intent,
					performedAt: draft.performedAt,
					score: score,
					memo: draft.normalizedMemo
				)
				try await sessionRepository.updateRecordingSession(session)
				return true
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
				performedAt: draft.performedAt,
				score: score,
				memo: draft.normalizedMemo
			)
			try await sessionRepository.saveNewRecordingSession(session)
			pendingSessionIdForSave = nil
			return true
		} catch {
			inlineErrorMessage = "保存に失敗しました。もう一度お試しください"
			return false
		}
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
			if candidates.isEmpty {
				trackSuggestionState = .noMatch
			} else {
				trackSuggestionState = .suggestions(Array(candidates.prefix(Self.maxTrackSuggestions)))
			}
		} catch is CancellationError {
			return
		} catch {
			guard !Task.isCancelled else { return }
			// 補助機能なので入力は妨げない。「候補なし」とは区別して何も出さない
			trackSuggestionState = .hidden
		}
	}

	func applyTrackSuggestion(_ suggestion: TrackSuggestion) {
		trackSuggestionState = .hidden
		trackState.manualName = suggestion.name
	}

	/// ``SingingSession`` の仕様（0〜100・小数第二位）に合わせ、Slider の `Double` 表現誤差を抑える。
	private static func normalizedScoreForPersistence(_ raw: Double) -> Double {
		let rounded = (raw * 100).rounded() / 100
		return min(100, max(0, rounded))
	}
}
