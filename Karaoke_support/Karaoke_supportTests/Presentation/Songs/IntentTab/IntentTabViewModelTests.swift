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
	/// テスト用セッション。`fetchAll` は ``SessionRepositoryProtocol`` の「日時降順」契約に合わせ、`performedAt` で降順に整えてから `offset` / `limit` でスライスする（代入順は不問）。
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
		let ordered = sessions.sorted { $0.performedAt > $1.performedAt }
		guard offset < ordered.count else { return [] }
		let end = min(offset + limit, ordered.count)
		return Array(ordered[offset..<end])
	}

	func fetchByIntent(_ intent: Intent, limit: Int, offset: Int) async throws -> [SingingSession] {
		[]
	}
}

/// 先頭ページ取得 ``fetchAll(limit:1, offset:0)`` だけを協調する。1回目は `await` で手を放し、2回目（別 ``load()``）が入ったら1回目を再開する。グローバルな `fetchAll` 回数ベースの sleep では月次ページング後に「2本目の先頭ページ」が再び1回目扱いになり失敗するため、先頭ページ専用の重なりを保証する。
@MainActor
private final class IntentTabSessionRepositoryStubOverlappingFirstPageFetch: SessionRepositoryProtocol {
	var sessions: [SingingSession] = []
	private var firstPageProbeCount = 0
	private var resumeFirstProbe: CheckedContinuation<Void, Never>?

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
		if limit == 1, offset == 0 {
			firstPageProbeCount += 1
			if firstPageProbeCount == 1 {
				await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
					resumeFirstProbe = c
				}
			} else if firstPageProbeCount == 2 {
				resumeFirstProbe?.resume()
				resumeFirstProbe = nil
			}
		}
		let ordered = sessions.sorted { $0.performedAt > $1.performedAt }
		guard offset < ordered.count else { return [] }
		let end = min(offset + limit, ordered.count)
		return Array(ordered[offset..<end])
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

/// `fetchAll` が失敗する（先頭ページ取得でエラー）場合の検証用。
@MainActor
private final class SessionRepositoryFetchAllThrowing: SessionRepositoryProtocol {
	struct StubError: Error {}

	func saveNewRecordingSession(_ session: SingingSession) async throws {}
	func updateRecordingSession(_ session: SingingSession) async throws {}
	func deleteRecordingSession(uuid: UUID) async throws {}
	func exists(uuid: UUID) async throws -> Bool { false }
	func fetchRecordingSession(uuid: UUID) async throws -> SingingSession {
		throw SessionRepositoryError.sessionNotFound(uuid)
	}

	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession] {
		throw StubError()
	}

	func fetchByIntent(_ intent: Intent, limit: Int, offset: Int) async throws -> [SingingSession] {
		[]
	}
}

// MARK: - Tests

@MainActor
final class IntentTabViewModelTests: XCTestCase {

	/// 概要: プレビュー用リポジトリで load() が正常完了し、Insight データが画面に反映されること（成功パスのスモークテスト）
	/// 前提(Given): PreviewInsightRepository と PreviewSessionRepository を注入した IntentTabViewModel
	/// 実行(When): vm.load() を呼ぶ
	/// 検証(Then): hasSingingData=true・isLoading=false・loadErrorMessage=nil・timeMachineRanking が非空・myAnthemRankings の件数が Intent.allCases.count と一致する
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

	/// 概要: セッションが 0 件のとき Insight 取得は呼ばれず、ランキングと統計が空になること
	/// 前提(Given): sessions=[] の SessionRepository スタブと InsightRepositorySpy
	/// 実行(When): vm.load() を呼ぶ
	/// 検証(Then): hasSingingData=false・isLoading=false・各ランキングが空・monthSessionCount=0・averageScoreThisMonth=nil・Insight の fetch が 0 回
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

	/// 概要: TimeMachine ランキング取得がエラーになったとき、loadErrorMessage にエラー文言がセットされること
	/// 前提(Given): 1 件のセッションを返すスタブと fetchTimeMachineRanking でエラーをスローする InsightRepository
	/// 実行(When): vm.load() を呼ぶ
	/// 検証(Then): hasSingingData=true・isLoading=false・loadErrorMessage が "読み込みに失敗しました。もう一度お試しください" になる
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

	/// 概要: セッション取得がエラーになったとき、loadErrorMessage にエラー文言がセットされること
	/// 前提(Given): fetchAll で常にエラーをスローする SessionRepository と InsightRepositorySpy
	/// 実行(When): vm.load() を呼ぶ
	/// 検証(Then): hasSingingData=false・isLoading=false・loadErrorMessage が "読み込みに失敗しました。もう一度お試しください" になる
	func testLoad_sessionRepositoryFetchAllThrows_setsLoadErrorMessage() async {
		let vm = IntentTabViewModel(
			insightRepository: InsightRepositorySpy(),
			sessionRepository: SessionRepositoryFetchAllThrowing()
		)
		await vm.load()

		XCTAssertFalse(vm.hasSingingData)
		XCTAssertFalse(vm.isLoading)
		XCTAssertEqual(vm.loadErrorMessage, "読み込みに失敗しました。もう一度お試しください")
	}

	/// 概要: load() を並行して 2 回呼んだとき、古い試行が中断され Insight フェッチは最新の 1 回だけ行われること
	/// 前提(Given): 先頭ページ取得を意図的に suspend できるスタブと InsightRepositorySpy。1 件のセッションを保有
	/// 実行(When): async let で load() を 2 並行起動し、両方 await する
	/// 検証(Then): loadErrorMessage=nil・hasSingingData=true・fetchTimeMachineCallCount=1・fetchMyAnthemCallCount=1（重複呼び出しなし）
	func testLoad_concurrentInvocations_onlyLatestAttemptFetchesInsight() async {
		let sessionStub = IntentTabSessionRepositoryStubOverlappingFirstPageFetch()
		let track = Track(userEnteredName: "並行")
		sessionStub.sessions = [
			SingingSession(track: track, intent: .shout, performedAt: .now, score: 50),
		]
		let insightSpy = InsightRepositorySpy()

		let vm = IntentTabViewModel(
			insightRepository: insightSpy,
			sessionRepository: sessionStub
		)

		async let first: Void = vm.load()
		async let second: Void = vm.load()
		await first
		await second

		XCTAssertNil(vm.loadErrorMessage)
		XCTAssertTrue(vm.hasSingingData)
		XCTAssertEqual(insightSpy.fetchTimeMachineCallCount, 1)
		XCTAssertEqual(insightSpy.fetchMyAnthemCallCount, 1)
	}

	/// 概要: 今月のセッション件数・平均スコアが先月以前を除いた正しい値になること
	/// 前提(Given): 先月末の 1 件（score=10）、今月 1 日+1 日の 1 件（score=80）、今月 1 日+2 日の 1 件（score=40）
	/// 実行(When): vm.load() を呼ぶ
	/// 検証(Then): monthSessionCount=2（今月分のみ）、averageScoreThisMonth=(80+40)/2=60 になる
	func testLoad_computeMonthStats_countsOnlyCurrentCalendarMonth() async throws {
		let cal = Calendar.current
		let now = Date()
		guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) else {
			XCTFail("monthStart")
			return
		}
		guard
			let beforeThisMonth = cal.date(byAdding: .day, value: -1, to: monthStart),
			let inMonth1 = cal.date(byAdding: .day, value: 1, to: monthStart),
			let inMonth2 = cal.date(byAdding: .day, value: 2, to: monthStart)
		else {
			XCTFail("Failed to calculate relative dates for month statistics")
			return
		}

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

	/// 概要: 月次統計の集計が fetchAll のページングを使って 600 件すべてを集計できること
	/// 前提(Given): 全件が今月内・score=50 の SingingSession が 600 件
	/// 実行(When): vm.load() を呼ぶ
	/// 検証(Then): monthSessionCount=600、averageScoreThisMonth=50 になる（ページング未実装なら件数不足で失敗する）
	func testLoad_computeMonthStats_paginatesFetchAll() async throws {
		let cal = Calendar.current
		let now = Date()
		guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) else {
			XCTFail("monthStart")
			return
		}
		guard let inMonth = cal.date(byAdding: .hour, value: 12, to: monthStart) else {
			XCTFail("Failed to calculate inMonth for pagination test")
			return
		}

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

	/// 概要: 翌月 1 日 0 時以降のセッションは「今月」カウントに含まれないこと（月末境界の検証）
	/// 前提(Given): 今月 5 日（score=80）と翌月 1 日 0 時ちょうど（score=99）のセッション 2 件
	/// 実行(When): vm.load() を呼ぶ
	/// 検証(Then): monthSessionCount=1（翌月分を除外）、averageScoreThisMonth=80 になる
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
		guard let inMonth = cal.date(byAdding: .day, value: 5, to: monthStart) else {
			XCTFail("Failed to calculate inMonth for month boundary test")
			return
		}
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
