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

@Suite("RecordingSheetViewModel の歌い切れたか（isCompleted）")
@MainActor
struct RecordingSheetViewModelCompletionTests {

	private let sessionRepository = CapturingSessionRepository()
	private let trackRepository = FixedTrackRepository()

	@Test("新しく開くと「歌い切れた」で、メモの案内は「ひとこと」")
	func startsCompleted() {
		let vm = RecordingSheetViewModel(trackMode: .manual, sessionRepository: sessionRepository, trackRepository: trackRepository)
		#expect(vm.draft.isCompleted)
		#expect(vm.memoPlaceholder == "ひとこと")
	}

	@Test("「歌い切れなかった」にすると、メモの案内が「どこが難しかった？」になる")
	func placeholderWhenNotCompleted() {
		let vm = RecordingSheetViewModel(trackMode: .manual, sessionRepository: sessionRepository, trackRepository: trackRepository)
		vm.draft.isCompleted = false
		#expect(vm.memoPlaceholder == "どこが難しかった？")
	}

	@Test("「歌い切れなかった」で、点数とメモが空のまま新しく保存できる")
	func newSaveWithoutScoreOrMemo() async {
		let vm = RecordingSheetViewModel(trackMode: .manual, sessionRepository: sessionRepository, trackRepository: trackRepository)
		vm.trackState.manualName = "紅蓮華"
		vm.draft.isCompleted = false

		#expect(await vm.save() != nil)
		#expect(sessionRepository.savedSessions.map(\.isCompleted) == [false])
		#expect(sessionRepository.savedSessions.map(\.score) == [nil])
		#expect(sessionRepository.savedSessions.map(\.memo) == [nil])
	}

	@Test("「歌い切れなかった」記録を編集で開くと、そのまま表示される")
	func editLoadsIsCompleted() {
		let session = SingingSession(track: trackRepository.track, intent: .shout, score: nil, isCompleted: false)
		let vm = RecordingSheetViewModel(editingSession: session, sessionRepository: sessionRepository, trackRepository: trackRepository)
		#expect(vm.draft.isCompleted == false)
	}

	@Test("「歌い切れなかった」記録を、触らずに編集して更新しても変わらない")
	func editKeepsIsCompleted() async {
		let session = SingingSession(track: trackRepository.track, intent: .shout, score: nil, isCompleted: false)
		let vm = RecordingSheetViewModel(editingSession: session, sessionRepository: sessionRepository, trackRepository: trackRepository)
		vm.draft.memo = "サビのキーが高かった"

		#expect(await vm.save() != nil)
		#expect(sessionRepository.updatedSessions.map(\.isCompleted) == [false])
	}

	@Test("編集で「歌い切れた」に変えて更新すると、歌い切れたで渡る")
	func editTurnsCompleted() async {
		let session = SingingSession(track: trackRepository.track, intent: .shout, score: nil, isCompleted: false)
		let vm = RecordingSheetViewModel(editingSession: session, sessionRepository: sessionRepository, trackRepository: trackRepository)
		vm.draft.isCompleted = true

		#expect(await vm.save() != nil)
		#expect(sessionRepository.updatedSessions.map(\.isCompleted) == [true])
	}
}
