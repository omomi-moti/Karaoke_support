import Foundation
import Testing

@testable import Karaoke_support

@MainActor
private final class TrackDetailSessionRepositoryStub: SessionRepositoryProtocol {
	var sessionsToReturn: [SingingSession] = []
	var errorToThrow: Error?

	func saveNewRecordingSession(_ session: SingingSession) async throws {}
	func updateRecordingSession(_ session: SingingSession) async throws {}
	func deleteRecordingSession(uuid: UUID) async throws {}
	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession] { [] }
	func fetchByIntent(_ intent: Intent, limit: Int, offset: Int) async throws -> [SingingSession] { [] }
	func exists(uuid: UUID) async throws -> Bool { false }
	func fetchRecordingSession(uuid: UUID) async throws -> SingingSession {
		throw SessionRepositoryError.sessionNotFound(uuid)
	}

	func fetchSessions(trackId: UUID) async throws -> [SingingSession] {
		if let errorToThrow {
			throw errorToThrow
		}
		return sessionsToReturn
	}
}

/// `fetchSessions` を継続で止め、キャンセル後に遅れて返る状況を作る。
@MainActor
private final class GatedSessionRepositoryStub: SessionRepositoryProtocol {
	var sessionsToReturn: [SingingSession] = []
	private var resumeFetch: CheckedContinuation<Void, Never>?
	private var notifyStarted: CheckedContinuation<Void, Never>?
	private var didStartFetch = false

	func saveNewRecordingSession(_ session: SingingSession) async throws {}
	func updateRecordingSession(_ session: SingingSession) async throws {}
	func deleteRecordingSession(uuid: UUID) async throws {}
	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession] { [] }
	func fetchByIntent(_ intent: Intent, limit: Int, offset: Int) async throws -> [SingingSession] { [] }
	func exists(uuid: UUID) async throws -> Bool { false }
	func fetchRecordingSession(uuid: UUID) async throws -> SingingSession {
		throw SessionRepositoryError.sessionNotFound(uuid)
	}

	func fetchSessions(trackId: UUID) async throws -> [SingingSession] {
		didStartFetch = true
		notifyStarted?.resume()
		notifyStarted = nil
		await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
			resumeFetch = c
		}
		return sessionsToReturn
	}

	func waitUntilFetchStarted() async {
		if didStartFetch { return }
		await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
			notifyStarted = c
		}
	}

	func finishFetch() {
		resumeFetch?.resume()
		resumeFetch = nil
	}
}

@Suite("TrackDetailViewModel")
@MainActor
struct TrackDetailViewModelTests {

	private func makeSessions(count: Int, track: Track) -> [SingingSession] {
		(1 ... count).map { index in
			SingingSession(
				track: track,
				intent: .shout,
				performedAt: Date(timeIntervalSince1970: Double(index) * 100),
				score: Double(60 + index % 41)
			)
		}
	}

	@Test("取得順のまま order を 1 から振り、統計を計算する")
	func loadMapsSessionsToPointsWithSummary() async throws {
		let track = Track(userEnteredName: "推移")
		let stub = TrackDetailSessionRepositoryStub()
		stub.sessionsToReturn = [
			SingingSession(track: track, intent: .shout, performedAt: Date(timeIntervalSince1970: 100), score: 80),
			SingingSession(track: track, intent: .emo, performedAt: Date(timeIntervalSince1970: 200), score: 90),
		]
		let vm = TrackDetailViewModel(sessionRepository: stub, trackId: track.id, trackTitle: "推移")

		await vm.load()

		#expect(vm.points.map(\.order) == [1, 2])
		#expect(vm.points.map(\.score) == [80, 90])
		#expect(vm.summary?.count == 2)
		#expect(vm.summary?.bestScore == 90)
		#expect(vm.isLoading == false)
		#expect(vm.loadErrorMessage == nil)
	}

	@Test("0 件では summary が nil になる")
	func loadWithNoSessionsClearsSummary() async {
		let track = Track(userEnteredName: "空")
		let stub = TrackDetailSessionRepositoryStub()
		let vm = TrackDetailViewModel(sessionRepository: stub, trackId: track.id, trackTitle: "空")

		await vm.load()

		#expect(vm.points.isEmpty)
		#expect(vm.summary == nil)
		#expect(vm.isLoading == false)
		#expect(vm.loadErrorMessage == nil)
	}

	@Test("取得に失敗したらエラー文言を出す")
	func loadFailureSetsErrorMessage() async {
		struct StubError: Error {}
		let track = Track(userEnteredName: "失敗")
		let stub = TrackDetailSessionRepositoryStub()
		stub.errorToThrow = StubError()
		let vm = TrackDetailViewModel(sessionRepository: stub, trackId: track.id, trackTitle: "失敗")

		await vm.load()

		#expect(vm.points.isEmpty)
		#expect(vm.summary == nil)
		#expect(vm.loadErrorMessage == "読み込みに失敗しました。もう一度お試しください")
		#expect(vm.isLoading == false)
	}

	@Test("グラフは直近 50 件に絞り、統計は全件から出す")
	func chartPointsAreTruncatedButSummaryUsesAllPoints() async throws {
		let track = Track(userEnteredName: "大量")
		let stub = TrackDetailSessionRepositoryStub()
		stub.sessionsToReturn = makeSessions(count: 60, track: track)
		let vm = TrackDetailViewModel(sessionRepository: stub, trackId: track.id, trackTitle: "大量")

		await vm.load()

		#expect(vm.points.count == 60)
		#expect(vm.summary?.count == 60)
		#expect(vm.isChartTruncated)
		#expect(vm.chartPoints.count == TrackDetailViewModel.maxChartPoints)
		#expect(vm.chartPoints.first?.order == 11)
		#expect(vm.chartPoints.last?.order == 60)
	}

	@Test("キャンセル済みのロードは遅れて返った結果で上書きしない")
	func cancelledLoadDoesNotApplyResult() async {
		let track = Track(userEnteredName: "キャンセル")
		let stub = GatedSessionRepositoryStub()
		stub.sessionsToReturn = [
			SingingSession(track: track, intent: .shout, performedAt: Date(timeIntervalSince1970: 100), score: 80),
		]
		let vm = TrackDetailViewModel(sessionRepository: stub, trackId: track.id, trackTitle: "キャンセル")

		let task = Task { await vm.load() }
		await stub.waitUntilFetchStarted()
		task.cancel()
		stub.finishFetch()
		await task.value

		#expect(vm.points.isEmpty)
		#expect(vm.summary == nil)
		#expect(vm.loadErrorMessage == nil)
		#expect(vm.isLoading)
	}
}
