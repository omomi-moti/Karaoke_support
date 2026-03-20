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

	init(
		trackMode: TrackInputMode,
		sessionRepository: any SessionRepositoryProtocol,
		trackRepository: any TrackRepositoryProtocol
	) {
		self.trackState = TrackInputState(mode: trackMode)
		self.sessionRepository = sessionRepository
		self.trackRepository = trackRepository
	}

	func validate() -> Bool {
		inlineErrorMessage = nil
		do {
			_ = try TrackResolver.resolveSelectedTrack(from: trackState)
			return true
		} catch {
			if case .manual = trackState.mode {
				trackState.validationMessage = "曲名を入力してください"
			}
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

			let session = SingingSession(
				track: track,
				intent: draft.intent,
				score: draft.score,
				memo: draft.normalizedMemo
			)

			try await sessionRepository.save(session: session)

			return true
		} catch {
			inlineErrorMessage = "保存に失敗しました。もう一度お試しください"
			return false
		}
	}
}

