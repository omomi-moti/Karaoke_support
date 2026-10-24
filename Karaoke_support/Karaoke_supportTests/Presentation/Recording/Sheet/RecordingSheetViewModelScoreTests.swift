import Foundation
import Testing

@testable import Karaoke_support

// MARK: - Stubs

@MainActor
private final class ScoreTestTrackRepositoryStub: TrackRepositoryProtocol {
	func searchLocal(query: String) async throws -> [Track] { [] }

	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?) async throws -> Track {
		Track(userEnteredName: userEnteredName ?? "fallback")
	}

	func incrementSingCount(trackId: UUID) async throws {}
}

/// 保存・更新に渡されたセッションを記録する。
@MainActor
private final class ScoreTestSessionRepositorySpy: SessionRepositoryProtocol {
	private(set) var savedScores: [Double?] = []
	private(set) var updatedScores: [Double?] = []
	private(set) var savedPerformedAts: [Date] = []
	private(set) var updatedPerformedAts: [Date] = []

	func saveNewRecordingSession(_ session: SingingSession) async throws {
		savedScores.append(session.score)
		savedPerformedAts.append(session.performedAt)
	}

	func updateRecordingSession(_ session: SingingSession) async throws {
		updatedScores.append(session.score)
		updatedPerformedAts.append(session.performedAt)
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

// MARK: - Tests

@Suite("RecordingSheetViewModel 点数入力・歌唱日時")
@MainActor
struct RecordingSheetViewModelScoreTests {

	private func makeNewRecordingViewModel(
		sessionRepository: ScoreTestSessionRepositorySpy,
		trackName: String = "Lemon"
	) -> RecordingSheetViewModel {
		let vm = RecordingSheetViewModel(
			trackMode: .manual,
			sessionRepository: sessionRepository,
			trackRepository: ScoreTestTrackRepositoryStub()
		)
		vm.trackState.manualName = trackName
		return vm
	}

	@Test("新規記録は点数が未入力の状態で始まる")
	func newRecordingStartsEmpty() {
		let vm = makeNewRecordingViewModel(sessionRepository: ScoreTestSessionRepositorySpy())
		#expect(vm.draft.score.value == nil)
	}

	@Test("点数が未入力のままでも保存でき、点数なし（nil）で保存される")
	func savingWithoutScoreSavesNil() async {
		let spy = ScoreTestSessionRepositorySpy()
		let vm = makeNewRecordingViewModel(sessionRepository: spy)

		let ok = await vm.save() != nil

		#expect(ok)
		#expect(spy.savedScores == [nil])
	}

	@Test("小数第3位まで打った点数がそのまま保存される")
	func savesThreeDecimalScore() async {
		let spy = ScoreTestSessionRepositorySpy()
		let vm = makeNewRecordingViewModel(sessionRepository: spy)
		vm.draft.score.applyEditedText("92345")

		let ok = await vm.save() != nil

		#expect(ok)
		#expect(spy.savedScores == [92.345])
	}

	@Test("編集で開くと元の点数が入っていて、直した点数で更新される")
	func editingStartsFromExistingScore() async {
		let spy = ScoreTestSessionRepositorySpy()
		let session = SingingSession(track: Track(userEnteredName: "Lemon"), intent: .emo, score: 88.5)
		let vm = RecordingSheetViewModel(
			editingSession: session,
			sessionRepository: spy,
			trackRepository: ScoreTestTrackRepositoryStub()
		)
		#expect(vm.draft.score.displayText == "88.500")

		vm.draft.score.applyEditedText("88501")
		let ok = await vm.save() != nil

		#expect(ok)
		#expect(spy.updatedScores == [88.501])
	}

	@Test("点数なしの記録を編集で開くと未入力で始まり、点数を足して更新できる")
	func editingSessionWithoutScore() async {
		let spy = ScoreTestSessionRepositorySpy()
		let session = SingingSession(track: Track(userEnteredName: "Lemon"), intent: .emo, score: nil)
		let vm = RecordingSheetViewModel(
			editingSession: session,
			sessionRepository: spy,
			trackRepository: ScoreTestTrackRepositoryStub()
		)
		#expect(vm.draft.score.value == nil)

		vm.draft.score.applyEditedText("90000")
		let ok = await vm.save() != nil

		#expect(ok)
		#expect(spy.updatedScores == [90])
	}

	@Test("編集で点数を消すと、点数なしに更新される")
	func clearingScoreWhileEditingSavesNil() async {
		let spy = ScoreTestSessionRepositorySpy()
		let session = SingingSession(track: Track(userEnteredName: "Lemon"), intent: .emo, score: 88.5)
		let vm = RecordingSheetViewModel(
			editingSession: session,
			sessionRepository: spy,
			trackRepository: ScoreTestTrackRepositoryStub()
		)

		vm.draft.score.applyEditedText("")
		let ok = await vm.save() != nil

		#expect(ok)
		#expect(spy.updatedScores == [nil])
	}

	// MARK: 歌唱日時

	@Test("新規記録の歌唱日時は、シートを開いた時刻ではなく保存した時刻になる")
	func newRecordingUsesSaveTimeAsPerformedAt() async {
		let spy = ScoreTestSessionRepositorySpy()
		let vm = makeNewRecordingViewModel(sessionRepository: spy)
		let saveTime = Date(timeIntervalSince1970: 1_800_000_000)
		vm.now = { saveTime }

		let ok = await vm.save() != nil

		#expect(ok)
		#expect(spy.savedPerformedAts == [saveTime])
	}

	@Test("編集では元の歌唱日時（または直した日時）のまま保存し、保存時刻で上書きしない")
	func editingKeepsPerformedAt() async {
		let spy = ScoreTestSessionRepositorySpy()
		let original = Date(timeIntervalSince1970: 1_700_000_000)
		let session = SingingSession(track: Track(userEnteredName: "Lemon"), intent: .emo, performedAt: original, score: 80)
		let vm = RecordingSheetViewModel(
			editingSession: session,
			sessionRepository: spy,
			trackRepository: ScoreTestTrackRepositoryStub()
		)
		vm.now = { Date(timeIntervalSince1970: 1_800_000_000) }

		let ok = await vm.save() != nil

		#expect(ok)
		#expect(spy.updatedPerformedAts == [original])
	}

	@Test("編集中の帯に出す元の歌唱日時は、新規では nil、編集では元の記録の日時になる")
	func originalPerformedAtForEditingBanner() {
		let original = Date(timeIntervalSince1970: 1_700_000_000)
		let session = SingingSession(track: Track(userEnteredName: "Lemon"), intent: .emo, performedAt: original, score: 80)
		let editing = RecordingSheetViewModel(
			editingSession: session,
			sessionRepository: ScoreTestSessionRepositorySpy(),
			trackRepository: ScoreTestTrackRepositoryStub()
		)
		let newRecording = makeNewRecordingViewModel(sessionRepository: ScoreTestSessionRepositorySpy())

		// 日時欄で日時を変えても、帯の日時は変わらない
		editing.draft.performedAt = Date(timeIntervalSince1970: 1_800_000_000)

		#expect(editing.editingSessionOriginalPerformedAt == original)
		#expect(newRecording.editingSessionOriginalPerformedAt == nil)
	}
}
