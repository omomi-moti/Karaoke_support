//
//  HistoryViewModelPaginationTests.swift
//  Karaoke_supportTests
//
//  I-015: `HistoryViewModel` の無限スクロール（offset ページング）検証。
//

import XCTest

@testable import Karaoke_support

@MainActor
private final class PagingStubSessionRepository: SessionRepositoryProtocol {
	var allPages: [[SingingSession]] = []
	var intentPages: [Intent: [[SingingSession]]] = [:]

	private(set) var fetchAllCalls: [(limit: Int, offset: Int)] = []
	private(set) var fetchByIntentCalls: [(intent: Intent, limit: Int, offset: Int)] = []

	func saveNewRecordingSession(_ session: SingingSession) async throws {}
	func updateRecordingSession(_ session: SingingSession) async throws {}
	func deleteRecordingSession(uuid: UUID) async throws {}
	func exists(uuid: UUID) async throws -> Bool { false }
	func fetchRecordingSession(uuid: UUID) async throws -> SingingSession {
		throw SessionRepositoryError.sessionNotFound(uuid)
	}

	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession] {
		fetchAllCalls.append((limit, offset))
		let page = offset / max(limit, 1)
		guard page >= 0, page < allPages.count else { return [] }
		return allPages[page]
	}

	func fetchByIntent(_ intent: Intent, limit: Int, offset: Int) async throws -> [SingingSession] {
		fetchByIntentCalls.append((intent, limit, offset))
		let pages = intentPages[intent] ?? []
		let page = offset / max(limit, 1)
		guard page >= 0, page < pages.count else { return [] }
		return pages[page]
	}
}

@MainActor
final class HistoryViewModelPaginationTests: XCTestCase {
	private func makeSessions(
		count: Int,
		startingAt: TimeInterval,
		intent: Intent = .shout
	) -> [SingingSession] {
		let track = Track(userEnteredName: "Paging Track")
		return (0..<count).map { i in
			SingingSession(
				track: track,
				intent: intent,
				performedAt: Date(timeIntervalSince1970: startingAt - Double(i)),
				score: Double(i)
			)
		}
	}

	func testLoadInitialAndLoadNextPage_UsesOffsetPagingForAll() async throws {
		let stub = PagingStubSessionRepository()
		stub.allPages = [
			makeSessions(count: 20, startingAt: 5_000),
			makeSessions(count: 10, startingAt: 4_000),
		]
		let vm = HistoryViewModel(sessionRepository: stub)
		vm.filter = .all

		await vm.loadInitial()
		XCTAssertEqual(stub.fetchAllCalls.map(\.offset), [0])
		XCTAssertEqual(vm.sessions.count, 20)
		XCTAssertTrue(vm.hasMorePages)

		let triggerID = try XCTUnwrap(vm.sessions.last?.id)
		await vm.loadNextPageIfNeeded(currentItemID: triggerID)

		XCTAssertEqual(stub.fetchAllCalls.map(\.offset), [0, 20])
		XCTAssertEqual(vm.sessions.count, 30)
		XCTAssertFalse(vm.hasMorePages)
	}

	func testLoadInitialAndLoadNextPage_UsesFetchByIntentPaging() async throws {
		let stub = PagingStubSessionRepository()
		stub.intentPages[.emo] = [
			makeSessions(count: 20, startingAt: 3_000, intent: .emo),
			makeSessions(count: 5, startingAt: 2_000, intent: .emo),
		]
		let vm = HistoryViewModel(sessionRepository: stub)
		vm.filter = .intent(.emo)

		await vm.loadInitial()
		XCTAssertEqual(stub.fetchByIntentCalls.map(\.offset), [0])
		XCTAssertEqual(vm.sessions.count, 20)

		let triggerID = try XCTUnwrap(vm.sessions.last?.id)
		await vm.loadNextPageIfNeeded(currentItemID: triggerID)

		XCTAssertEqual(stub.fetchByIntentCalls.map(\.offset), [0, 20])
		XCTAssertEqual(vm.sessions.count, 25)
		XCTAssertFalse(vm.hasMorePages)
	}

	func testLoadNextPageIfNeeded_DoesNothingWhenNotNearBottom() async throws {
		let stub = PagingStubSessionRepository()
		stub.allPages = [makeSessions(count: 20, startingAt: 1_000), makeSessions(count: 20, startingAt: 900)]
		let vm = HistoryViewModel(sessionRepository: stub)
		vm.filter = .all

		await vm.loadInitial()
		let firstID = try XCTUnwrap(vm.sessions.first?.id)
		await vm.loadNextPageIfNeeded(currentItemID: firstID)

		XCTAssertEqual(stub.fetchAllCalls.map(\.offset), [0], "末尾付近でない行では追加読み込みしない")
		XCTAssertEqual(vm.sessions.count, 20)
	}
}
