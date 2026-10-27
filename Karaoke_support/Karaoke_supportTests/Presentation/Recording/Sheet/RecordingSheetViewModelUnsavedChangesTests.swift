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

@Suite("RecordingSheetViewModel の閉じる前の確認と最初のカーソル")
@MainActor
struct RecordingSheetViewModelUnsavedChangesTests {

	private let sessionRepository = CapturingSessionRepository()
	private let trackRepository = FixedTrackRepository()

	@Test("＋で空のシートを開いた直後は、変更なしで、曲名にカーソルを置く")
	func newSheetStartsClean() {
		let vm = RecordingSheetViewModel(trackMode: .manual, sessionRepository: sessionRepository, trackRepository: trackRepository)
		#expect(!vm.hasUnsavedChanges)
		#expect(vm.focusesTrackNameOnOpen)
	}

	@Test("曲名・気分・ハートのどれかを変えると、変更ありになる")
	func changesAreDetected() {
		let vm = RecordingSheetViewModel(trackMode: .manual, sessionRepository: sessionRepository, trackRepository: trackRepository)
		vm.trackState.manualName = "紅蓮華"
		#expect(vm.hasUnsavedChanges)

		vm.trackState.manualName = ""
		#expect(!vm.hasUnsavedChanges)

		vm.draft.intent = .emo
		#expect(vm.hasUnsavedChanges)

		vm.draft.intent = .shout
		vm.draft.wantAgain = true
		#expect(vm.hasUnsavedChanges)
	}

	@Test("曲と気分を入れて開いた直後は、変更なしで、カーソルを置かない")
	func selectedTrackStartsClean() throws {
		let selected = try #require(SelectedTrack(spotifyTrackId: nil, userEnteredName: "涙そうそう"))
		let vm = RecordingSheetViewModel(selectedTrack: selected, intent: .emo, source: .suggestion, sessionRepository: sessionRepository, trackRepository: trackRepository)
		#expect(!vm.hasUnsavedChanges)
		#expect(!vm.focusesTrackNameOnOpen)
	}

	@Test("編集で開いた直後は変更なしで、メモを変えると変更ありになる。カーソルは置かない")
	func editStartsCleanAndDetectsChanges() {
		let session = SingingSession(track: trackRepository.track, intent: .emo, score: 90, memo: "前のメモ", wantAgain: true)
		let vm = RecordingSheetViewModel(editingSession: session, sessionRepository: sessionRepository, trackRepository: trackRepository)
		#expect(!vm.hasUnsavedChanges)
		#expect(!vm.focusesTrackNameOnOpen)

		vm.draft.memo = "新しいメモ"
		#expect(vm.hasUnsavedChanges)
	}
}
