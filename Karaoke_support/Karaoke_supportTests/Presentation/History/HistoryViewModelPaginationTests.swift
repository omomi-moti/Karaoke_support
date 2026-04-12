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

	/// 概要: filter=.all のとき loadInitial と loadNextPageIfNeeded が offset ページングで fetchAll を呼ぶこと
	/// 前提(Given): 第 1 ページ 20 件・第 2 ページ 10 件を返すスタブで filter=.all を設定
	/// 実行(When): loadInitial() → sessions 末尾の ID で loadNextPageIfNeeded() を順に呼ぶ
	/// 検証(Then): fetchAll の offset が [0, 20] で呼ばれ、sessions が 30 件に増え、hasMorePages が false になる
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

	/// 概要: filter=.intent(.emo) のとき offset ページングで fetchByIntent(.emo) が呼ばれること
	/// 前提(Given): .emo の第 1 ページ 20 件・第 2 ページ 5 件を返すスタブで filter=.intent(.emo) を設定
	/// 実行(When): loadInitial() → sessions 末尾 ID で loadNextPageIfNeeded() を順に呼ぶ
	/// 検証(Then): fetchByIntent の offset が [0, 20] で呼ばれ、sessions が 25 件に増え、hasMorePages が false になる
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

	/// 概要: リストの先頭付近のアイテムで loadNextPageIfNeeded を呼んでも追加フェッチが発生しないこと
	/// 前提(Given): 20 件の第 1 ページをロード済みの状態
	/// 実行(When): sessions の先頭アイテムの ID で loadNextPageIfNeeded(currentItemID:) を呼ぶ
	/// 検証(Then): fetchAll の呼び出し offset が [0] のまま増えず、sessions 件数も 20 件から変わらない
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

	/// 概要: 表示件数上限（500 件）に達したら sessions が先頭 500 件に切り詰められ、hasMorePages が false になること（I-015）
	/// 前提(Given): 20 件 × 26 ページ = 520 件を返すスタブで filter=.all を設定
	/// 実行(When): loadInitial() の後、sessions 末尾 ID で loadNextPageIfNeeded を 25 回繰り返す
	/// 検証(Then): sessions が 500 件に切り詰められ、hasMorePages=false となり、その後の loadNextPageIfNeeded で Repository が呼ばれなくなる
	func testPagination_StopsAtDisplayedSessionCap() async throws {
		let stub = PagingStubSessionRepository()
		// 20 件 × 26 ページ = 520 件 → 1 回目の append で 500 超え → prefix(500) と hasMorePages = false
		stub.allPages = (0..<26).map { page in
			makeSessions(count: 20, startingAt: 100_000 - Double(page * 20))
		}
		let vm = HistoryViewModel(sessionRepository: stub)
		vm.filter = .all

		await vm.loadInitial()
		XCTAssertEqual(vm.sessions.count, 20)
		XCTAssertTrue(vm.hasMorePages)

		for _ in 0..<25 {
			let lastID = try XCTUnwrap(vm.sessions.last?.id)
			await vm.loadNextPageIfNeeded(currentItemID: lastID)
		}

		XCTAssertEqual(vm.sessions.count, 500, "520 件まで読んだあと先頭 500 件に切り詰め")
		XCTAssertFalse(vm.hasMorePages, "上限到達後はこれ以上ページングしない")

		let fetchCountAfterCap = stub.fetchAllCalls.count
		XCTAssertEqual(
			stub.fetchAllCalls.map(\.offset),
			(0..<26).map { $0 * 20 },
			"offset 0 … 500 まで 26 回フェッチ"
		)

		let lastID = try XCTUnwrap(vm.sessions.last?.id)
		await vm.loadNextPageIfNeeded(currentItemID: lastID)
		XCTAssertEqual(
			stub.fetchAllCalls.count,
			fetchCountAfterCap,
			"hasMorePages が false のときは Repository を呼ばない"
		)
	}
}
