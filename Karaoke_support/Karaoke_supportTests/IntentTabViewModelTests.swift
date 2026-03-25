//
//  IntentTabViewModelTests.swift
//  Karaoke_supportTests
//
//  I-017: `IntentTabViewModel` のスモーク・分岐・統計の検証。
//

import XCTest
@testable import Karaoke_support

// MARK: - Stubs

@MainActor
private final class IntentTabSessionRepositoryStub: SessionRepositoryProtocol {
	/// `fetchAll` はこの配列を `offset` / `limit` でスライスする（日時降順などの並びはテストでは不問）。
	var sessions: [SingingSession] = []

	func saveNewRecordingSession(_ session: SingingSession) async throws {}
	func updateRecordingSession(_ session: SingingSession) async throws {}
	func deleteRecordingSession(uuid: UUID) async throws {}
	func exists(uuid: UUID) async throws -> Bool { false }
	func fetchRecordingSession(uuid: UUID) async throws -> SingingSession {
		throw SessionRepositoryError.sessionNotFound(uuid)
	}

	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession] {
		guard limit >= 0, offset >= 0 else {
			throw SessionRepositoryError.invalidParameter("limit and offset must be non-negative")
		}
		guard offset < sessions.count else { return [] }
		let end = min(offset + limit, sessions.count)
		return Array(sessions[offset..<end])
	}

	func fetchByIntent(_ intent: Intent, limit: Int, offset: Int) async throws -> [SingingSession] {
		[]
	}
}

@MainActor
private final class InsightRepositorySpy: InsightRepositoryProtocol {
	private(set) var fetchTimeMachineCallCount = 0
	private(set) var fetchMyAnthemCallCount = 0

	func fetchTimeMachineRanking() async throws -> [InsightTrackCountRanking] {
		fetchTimeMachineCallCount += 1
		return []
	}

	func fetchMyAnthemRankings(period: InsightPeriod) async throws -> [MyAnthemRanking] {
		fetchMyAnthemCallCount += 1
		return []
	}
}

@MainActor
private final class InsightRepositoryThrowingOnTimeMachine: InsightRepositoryProtocol {
	func fetchTimeMachineRanking() async throws -> [InsightTrackCountRanking] {
		struct TestError: Error {}
		throw TestError()
	}

	func fetchMyAnthemRankings(period: InsightPeriod) async throws -> [MyAnthemRanking] {
		[]
	}
}

// MARK: - Tests

@MainActor
final class IntentTabViewModelTests: XCTestCase {
	func testLoad_withPreviewRepositories_loadsInsightData() async {
		let vm = IntentTabViewModel(
			insightRepository: PreviewInsightRepository(),
			sessionRepository: PreviewSessionRepository()
		)
		await vm.load()
		XCTAssertTrue(vm.hasSingingData)
		XCTAssertFalse(vm.isLoading)
		XCTAssertNil(vm.loadErrorMessage)
		XCTAssertFalse(vm.timeMachineRanking.isEmpty)
		XCTAssertEqual(vm.myAnthemRankings.count, Intent.allCases.count)
	}

	func testLoad_emptySessions_doesNotCallInsightAndClearsRankings() async {
		let sessionStub = IntentTabSessionRepositoryStub()
		sessionStub.sessions = []
		let insightSpy = InsightRepositorySpy()

		let vm = IntentTabViewModel(
			insightRepository: insightSpy,
			sessionRepository: sessionStub
		)
		await vm.load()

		XCTAssertFalse(vm.hasSingingData)
		XCTAssertFalse(vm.isLoading)
		XCTAssertNil(vm.loadErrorMessage)
		XCTAssertTrue(vm.timeMachineRanking.isEmpty)
		XCTAssertTrue(vm.myAnthemRankings.isEmpty)
		XCTAssertEqual(vm.monthSessionCount, 0)
		XCTAssertNil(vm.averageScoreThisMonth)
		XCTAssertEqual(insightSpy.fetchTimeMachineCallCount, 0)
		XCTAssertEqual(insightSpy.fetchMyAnthemCallCount, 0)
	}

	func testLoad_insightTimeMachineThrows_setsLoadErrorMessage() async {
		let sessionStub = IntentTabSessionRepositoryStub()
		let track = Track(userEnteredName: "テスト曲")
		sessionStub.sessions = [
			SingingSession(track: track, intent: .shout, performedAt: .now, score: 50),
		]

		let vm = IntentTabViewModel(
			insightRepository: InsightRepositoryThrowingOnTimeMachine(),
			sessionRepository: sessionStub
		)
		await vm.load()

		XCTAssertTrue(vm.hasSingingData)
		XCTAssertFalse(vm.isLoading)
		XCTAssertEqual(vm.loadErrorMessage, "読み込みに失敗しました。もう一度お試しください")
	}

	func testLoad_computeMonthStats_countsOnlyCurrentCalendarMonth() async throws {
		let cal = Calendar.current
		let now = Date()
		guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) else {
			XCTFail("monthStart")
			return
		}
		let beforeThisMonth = cal.date(byAdding: .day, value: -1, to: monthStart)!
		let inMonth1 = cal.date(byAdding: .day, value: 1, to: monthStart)!
		let inMonth2 = cal.date(byAdding: .day, value: 2, to: monthStart)!

		let track = Track(userEnteredName: "統計テスト")
		let sessionStub = IntentTabSessionRepositoryStub()
		sessionStub.sessions = [
			SingingSession(track: track, intent: .shout, performedAt: beforeThisMonth, score: 10),
			SingingSession(track: track, intent: .emo, performedAt: inMonth1, score: 80),
			SingingSession(track: track, intent: .practice, performedAt: inMonth2, score: 40),
		]

		let vm = IntentTabViewModel(
			insightRepository: InsightRepositorySpy(),
			sessionRepository: sessionStub
		)
		await vm.load()

		XCTAssertNil(vm.loadErrorMessage)
		XCTAssertEqual(vm.monthSessionCount, 2)
		let average = try XCTUnwrap(vm.averageScoreThisMonth)
		XCTAssertEqual(average, 60, accuracy: 0.001)
	}

	func testLoad_computeMonthStats_paginatesFetchAll() async throws {
		let cal = Calendar.current
		let now = Date()
		guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) else {
			XCTFail("monthStart")
			return
		}
		let inMonth = cal.date(byAdding: .hour, value: 12, to: monthStart)!

		let track = Track(userEnteredName: "ページング")
		var list: [SingingSession] = []
		for i in 0..<600 {
			list.append(
				SingingSession(
					track: track,
					intent: .shout,
					performedAt: inMonth.addingTimeInterval(Double(i)),
					score: 50
				)
			)
		}

		let sessionStub = IntentTabSessionRepositoryStub()
		sessionStub.sessions = list

		let vm = IntentTabViewModel(
			insightRepository: InsightRepositorySpy(),
			sessionRepository: sessionStub
		)
		await vm.load()

		XCTAssertEqual(vm.monthSessionCount, 600)
		let averagePaging = try XCTUnwrap(vm.averageScoreThisMonth)
		XCTAssertEqual(averagePaging, 50, accuracy: 0.001)
	}

	/// `performedAt` が翌月1日0時以降のセッションは「今月」に含めない（`monthStart ..< nextMonthStart`）。
	func testLoad_computeMonthStats_excludesNextMonthAndLater() async throws {
		let cal = Calendar.current
		guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date())) else {
			XCTFail("monthStart")
			return
		}
		guard let nextMonthStart = cal.date(byAdding: .month, value: 1, to: monthStart) else {
			XCTFail("nextMonthStart")
			return
		}
		let inMonth = cal.date(byAdding: .day, value: 5, to: monthStart)!
		let track = Track(userEnteredName: "境界")
		let sessionStub = IntentTabSessionRepositoryStub()
		sessionStub.sessions = [
			SingingSession(track: track, intent: .shout, performedAt: inMonth, score: 80),
			SingingSession(track: track, intent: .shout, performedAt: nextMonthStart, score: 99),
		]

		let vm = IntentTabViewModel(
			insightRepository: InsightRepositorySpy(),
			sessionRepository: sessionStub
		)
		await vm.load()

		XCTAssertNil(vm.loadErrorMessage)
		XCTAssertEqual(vm.monthSessionCount, 1)
		let average = try XCTUnwrap(vm.averageScoreThisMonth)
		XCTAssertEqual(average, 80, accuracy: 0.001)
	}
}
