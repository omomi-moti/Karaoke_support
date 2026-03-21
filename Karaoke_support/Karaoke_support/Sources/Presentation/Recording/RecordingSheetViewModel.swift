import Foundation
import Observation

@MainActor
@Observable
final class RecordingSheetViewModel {
	var trackState: TrackInputState
	var draft: RecordingDraft = .init()

	var isSaving: Bool = false
	var inlineErrorMessage: String? = nil

	private let sessionRepository: any SessionRepositoryProtocol
	private let trackRepository: any TrackRepositoryProtocol

	/// 保存失敗後の再試行で同一 ``SingingSession.id`` を使う（I-011 Idempotency Key）。成功時は `nil` に戻す。
	private var pendingSessionIdForSave: UUID?

	init(
		trackMode: TrackInputMode,
		sessionRepository: any SessionRepositoryProtocol,
		trackRepository: any TrackRepositoryProtocol
	) {
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
		self.sessionRepository = sessionRepository
		self.trackRepository = trackRepository
		self.trackState = Self.trackInputState(from: selectedTrack)
	}

	private static func trackInputState(from selected: SelectedTrack) -> TrackInputState {
		switch (selected.spotifyTrackId, selected.userEnteredName) {
		case let (spotify?, nil):
			return TrackInputState(
				mode: .spotifyHistory(spotifyTrackId: spotify, displayName: Self.fallbackDisplayName(forSpotifyId: spotify))
			)
		case let (nil, name?):
			var state = TrackInputState(mode: .manual)
			state.manualName = name
			return state
		case let (spotify?, name?):
			return TrackInputState(
				mode: .spotifyHistory(spotifyTrackId: spotify, displayName: name)
			)
		case (nil, nil):
			fatalError("SelectedTrack must have at least one non-empty field")
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
