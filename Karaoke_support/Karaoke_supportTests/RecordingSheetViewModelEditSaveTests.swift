//
//  RecordingSheetViewModelEditSaveTests.swift
//  Karaoke_supportTests
//
//  I-014-C: 編集時は `updateRecordingSession` が呼ばれる（新規保存に流さない）。
//

import XCTest

@testable import Karaoke_support

@MainActor
private final class SingletonTrackForEditTests: TrackRepositoryProtocol {
	let fixedTrack: Track

	init(fixedTrack: Track) {
		self.fixedTrack = fixedTrack
	}

	func searchLocal(query: String) async throws -> [Track] { [] }

	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?) async throws -> Track {
		fixedTrack
	}

	func incrementSingCount(trackId: UUID) async throws {}
}

@MainActor
private final class SpySessionRepositoryForEdit: SessionRepositoryProtocol {
	let sessionToEdit: SingingSession
	private(set) var didCallUpdate = false
	private(set) var didCallSaveNew = false

	init(sessionToEdit: SingingSession) {
		self.sessionToEdit = sessionToEdit
	}

	func saveNewRecordingSession(_ session: SingingSession) async throws {
		didCallSaveNew = true
	}

	func updateRecordingSession(_ session: SingingSession) async throws {
		didCallUpdate = true
	}

	func deleteRecordingSession(uuid: UUID) async throws {}

	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession] { [] }

	func fetchByIntent(_ intent: Intent, limit: Int, offset: Int) async throws -> [SingingSession] { [] }

	func exists(uuid: UUID) async throws -> Bool { false }

	func fetchRecordingSession(uuid: UUID) async throws -> SingingSession {
		guard uuid == sessionToEdit.id else {
			throw SessionRepositoryError.sessionNotFound(uuid)
		}
		return sessionToEdit
	}
}

@MainActor
final class RecordingSheetViewModelEditSaveTests: XCTestCase {

	func testSave_UsesUpdateRecordingSessionWhenEditing() async {
		let track = Track(userEnteredName: "編集テスト曲")
		let session = SingingSession(
			track: track,
			intent: .emo,
			performedAt: Date(timeIntervalSince1970: 1_700_000_000),
			score: 77.5,
			memo: "メモ"
		)
		let spy = SpySessionRepositoryForEdit(sessionToEdit: session)
		let tracks = SingletonTrackForEditTests(fixedTrack: track)

		let vm = RecordingSheetViewModel(
			editingSession: session,
			sessionRepository: spy,
			trackRepository: tracks
		)

		let ok = await vm.save()
		XCTAssertTrue(ok)
		XCTAssertTrue(spy.didCallUpdate)
		XCTAssertFalse(spy.didCallSaveNew)
	}
}
