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

	/// ``SingingSession`` の仕様（0〜100・小数第二位）に合わせ、Slider の `Double` 表現誤差を抑える。
	private static func normalizedScoreForPersistence(_ raw: Double) -> Double {
		let rounded = (raw * 100).rounded() / 100
		return min(100, max(0, rounded))
	}
}
