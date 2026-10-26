import Foundation
import Testing

@testable import Karaoke_support

@MainActor
private final class FixedTrackRepository: TrackRepositoryProtocol {
	let track = Track(userEnteredName: "曲")

	func searchLocal(query: String) async throws -> [Track] { [] }

	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?) async throws -> Track { track }

	func incrementSingCount(trackId: UUID) async throws {}
}

/// 新しく保存した記録と、更新した記録を覚えておく。
@MainActor
private final class CapturingSessionRepository: SessionRepositoryProtocol {
	private(set) var savedSessions: [SingingSession] = []
	private(set) var updatedSessions: [SingingSession] = []

	func saveNewRecordingSession(_ session: SingingSession) async throws {
		savedSessions.append(session)
	}

	func updateRecordingSession(_ session: SingingSession) async throws {
		updatedSessions.append(session)
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

@Suite("RecordingSheetViewModel のハート（wantAgain）")
@MainActor
struct RecordingSheetViewModelWantAgainTests {

	private let sessionRepository = CapturingSessionRepository()
	private let trackRepository = FixedTrackRepository()

	@Test("新しく開くと、ハートは OFF")
	func startsOff() {
		let vm = RecordingSheetViewModel(trackMode: .manual, sessionRepository: sessionRepository, trackRepository: trackRepository)
		#expect(vm.draft.wantAgain == false)
	}

	@Test("ハートを ON にして新しく保存すると、記録にハートが付く")
	func newSavePassesWantAgain() async {
		let vm = RecordingSheetViewModel(trackMode: .manual, sessionRepository: sessionRepository, trackRepository: trackRepository)
		vm.trackState.manualName = "涙そうそう"
		vm.draft.wantAgain = true

		#expect(await vm.save() != nil)
		#expect(sessionRepository.savedSessions.map(\.wantAgain) == [true])
	}

	@Test("ハートを付けた記録を編集で開くと、ハートが ON で表示される")
	func editLoadsWantAgain() {
		let session = SingingSession(track: trackRepository.track, intent: .emo, score: 90, wantAgain: true)
		let vm = RecordingSheetViewModel(editingSession: session, sessionRepository: sessionRepository, trackRepository: trackRepository)
		#expect(vm.draft.wantAgain)
	}

	@Test("ハートを付けた記録を、ハートに触らず編集して更新しても、ハートは外れない")
	func editKeepsWantAgain() async {
		let session = SingingSession(track: trackRepository.track, intent: .emo, score: 90, wantAgain: true)
		let vm = RecordingSheetViewModel(editingSession: session, sessionRepository: sessionRepository, trackRepository: trackRepository)
		vm.draft.memo = "サビが出た"

		#expect(await vm.save() != nil)
		#expect(sessionRepository.updatedSessions.map(\.wantAgain) == [true])
	}

	@Test("編集でハートを外して更新すると、ハートなしで渡る")
	func editTurnsOff() async {
		let session = SingingSession(track: trackRepository.track, intent: .emo, score: 90, wantAgain: true)
		let vm = RecordingSheetViewModel(editingSession: session, sessionRepository: sessionRepository, trackRepository: trackRepository)
		vm.draft.wantAgain = false

		#expect(await vm.save() != nil)
		#expect(sessionRepository.updatedSessions.map(\.wantAgain) == [false])
	}
}
