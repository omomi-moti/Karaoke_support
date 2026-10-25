import Foundation
import Testing

@testable import Karaoke_support

@MainActor
private final class FixedTrackRepository: TrackRepositoryProtocol {
	let track: Track

	init(track: Track) {
		self.track = track
	}

	func searchLocal(query: String) async throws -> [Track] { [] }

	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?) async throws -> Track { track }

	func incrementSingCount(trackId: UUID) async throws {}
}

@MainActor
private final class StubSessionRepository: SessionRepositoryProtocol {
	var failsOnSave = false

	func saveNewRecordingSession(_ session: SingingSession) async throws {
		if failsOnSave { throw SessionRepositoryError.invalidParameter("stub") }
	}

	func updateRecordingSession(_ session: SingingSession) async throws {
		if failsOnSave { throw SessionRepositoryError.invalidParameter("stub") }
	}

	func deleteRecordingSession(uuid: UUID) async throws {}

	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession] { [] }

	func fetchByIntent(_ intent: Intent, limit: Int, offset: Int) async throws -> [SingingSession] { [] }

	func exists(uuid: UUID) async throws -> Bool { false }

	func fetchRecordingSession(uuid: UUID) async throws -> SingingSession {
		throw SessionRepositoryError.sessionNotFound(uuid)
	}

	func fetchSessions(trackId: UUID) async throws -> [SingingSession] { [] }
}

@Suite("RecordingSheetViewModel.save() が返す保存した記録の要約")
@MainActor
struct RecordingSheetViewModelSavedRecordingTests {

	@Test("新規で保存すると、新規の記録として要約が返る")
	func newSaveReturnsSummary() async throws {
		let track = Track(userEnteredName: "Pretender")
		let vm = RecordingSheetViewModel(
			trackMode: .manual,
			sessionRepository: StubSessionRepository(),
			trackRepository: FixedTrackRepository(track: track)
		)
		vm.trackState.manualName = "Pretender"
		vm.draft.intent = .emo
		vm.draft.score = ScoreDigitInput(score: 91.25)

		let saved = try #require(await vm.save())

		#expect(saved.trackId == track.id)
		#expect(saved.trackTitle == "Pretender")
		#expect(saved.intent == .emo)
		#expect(saved.score == 91.25)
		#expect(saved.isNewRecording)
	}

	@Test("編集して更新すると、新規ではない記録として要約が返る")
	func editSaveReturnsSummaryAsNotNew() async throws {
		let track = Track(userEnteredName: "編集する曲")
		let session = SingingSession(track: track, intent: .practice, score: nil)
		let vm = RecordingSheetViewModel(
			editingSession: session,
			sessionRepository: StubSessionRepository(),
			trackRepository: FixedTrackRepository(track: track)
		)

		let saved = try #require(await vm.save())

		#expect(saved.sessionId == session.id)
		#expect(saved.score == nil)
		#expect(!saved.isNewRecording)
	}

	@Test("保存に失敗したときは nil が返る")
	func failedSaveReturnsNil() async {
		let sessions = StubSessionRepository()
		sessions.failsOnSave = true
		let vm = RecordingSheetViewModel(
			trackMode: .manual,
			sessionRepository: sessions,
			trackRepository: FixedTrackRepository(track: Track(userEnteredName: "失敗する曲"))
		)
		vm.trackState.manualName = "失敗する曲"

		#expect(await vm.save() == nil)
	}

	@Test("曲名が空で保存できないときは nil が返る")
	func invalidInputReturnsNil() async {
		let vm = RecordingSheetViewModel(
			trackMode: .manual,
			sessionRepository: StubSessionRepository(),
			trackRepository: FixedTrackRepository(track: Track(userEnteredName: "使わない曲"))
		)

		#expect(await vm.save() == nil)
	}
}
