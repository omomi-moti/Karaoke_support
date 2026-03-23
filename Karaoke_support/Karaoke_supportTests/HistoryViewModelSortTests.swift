//
//  HistoryViewModelSortTests.swift
//  Karaoke_supportTests
//
//  I-014-B: `HistoryViewModel` が **filter → sort** の順で表示する（Repository はメモリ上のスタブ）。
//

import XCTest

@testable import Karaoke_support

@MainActor
private final class StubSessionRepository: SessionRepositoryProtocol {
	var fetchAllResult: [SingingSession] = []

	func saveNewRecordingSession(_ session: SingingSession) async throws {}

	func updateRecordingSession(_ session: SingingSession) async throws {}

	func deleteRecordingSession(uuid: UUID) async throws {}

	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession] {
		let start = min(offset, fetchAllResult.count)
		let end = min(offset + max(limit, 0), fetchAllResult.count)
		return Array(fetchAllResult[start..<end])
	}

	func fetchByIntent(_ intent: Intent, limit: Int, offset: Int) async throws -> [SingingSession] {
		let rows = try await fetchAll(limit: limit, offset: offset)
		return rows.filter { $0.intent == intent }
	}

	func exists(uuid: UUID) async throws -> Bool { false }

	func fetchRecordingSession(uuid: UUID) async throws -> SingingSession {
		throw SessionRepositoryError.sessionNotFound(uuid)
	}
}

@MainActor
final class HistoryViewModelSortTests: XCTestCase {

	func testLoad_SortsByScoreDescendingAfterFetch() async {
		let stub = StubSessionRepository()
		let track = Track(userEnteredName: "Stub Track")
		let lowFirst = SingingSession(
			track: track,
			intent: .shout,
			performedAt: Date(timeIntervalSince1970: 50),
			score: 10
		)
		let highSecond = SingingSession(
			track: track,
			intent: .shout,
			performedAt: Date(timeIntervalSince1970: 100),
			score: 95
		)
		// Repository の配列順はバラバラでも、VM が sortOrder で整列する
		stub.fetchAllResult = [lowFirst, highSecond]

		let vm = HistoryViewModel(sessionRepository: stub)
		vm.filter = .all
		vm.sortOrder = .scoreDescending
		await vm.load()

		XCTAssertNil(vm.loadErrorMessage)
		XCTAssertEqual(vm.sessions.map(\.score), [95, 10])
	}

	func testLoad_AppliesIntentFilterThenSortByPerformedAtAscending() async {
		let stub = StubSessionRepository()
		let t1 = Track(userEnteredName: "A")
		let t2 = Track(userEnteredName: "B")
		let shoutOld = SingingSession(
			track: t1,
			intent: .shout,
			performedAt: Date(timeIntervalSince1970: 100),
			score: 50
		)
		let emoNew = SingingSession(
			track: t2,
			intent: .emo,
			performedAt: Date(timeIntervalSince1970: 500),
			score: 99
		)
		let shoutNew = SingingSession(
			track: t1,
			intent: .shout,
			performedAt: Date(timeIntervalSince1970: 400),
			score: 60
		)
		stub.fetchAllResult = [emoNew, shoutOld, shoutNew]

		let vm = HistoryViewModel(sessionRepository: stub)
		vm.filter = .intent(.shout)
		vm.sortOrder = .performedAtAscending
		await vm.load()

		XCTAssertEqual(vm.sessions.count, 2)
		XCTAssertEqual(vm.sessions.map(\.performedAt), [shoutOld.performedAt, shoutNew.performedAt])
	}

	func testApplySortToLoadedSessions_ReordersWithoutRefetch() async {
		let stub = StubSessionRepository()
		let track = Track(userEnteredName: "R")
		let a = SingingSession(track: track, intent: .practice, performedAt: Date(timeIntervalSince1970: 10), score: 20)
		let b = SingingSession(track: track, intent: .practice, performedAt: Date(timeIntervalSince1970: 20), score: 80)
		stub.fetchAllResult = [a, b]

		let vm = HistoryViewModel(sessionRepository: stub)
		vm.filter = .all
		vm.sortOrder = .performedAtDescending
		await vm.load()
		XCTAssertEqual(vm.sessions.map(\.score), [80, 20])

		vm.sortOrder = .scoreAscending
		vm.applySortToLoadedSessions()
		XCTAssertEqual(vm.sessions.map(\.score), [20, 80])
	}
}
