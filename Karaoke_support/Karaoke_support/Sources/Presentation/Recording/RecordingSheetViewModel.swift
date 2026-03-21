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
			let session = SingingSession(
				track: track,
				intent: draft.intent,
				score: score,
				memo: draft.normalizedMemo
			)
			try await sessionRepository.saveNewRecordingSession(session)
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
