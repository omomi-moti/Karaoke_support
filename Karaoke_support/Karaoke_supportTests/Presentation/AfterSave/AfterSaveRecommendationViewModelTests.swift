import Foundation
import Testing

@testable import Karaoke_support

@MainActor
private final class StubTrackStatsRepository: TrackStatsRepositoryProtocol {
	var stats: [TrackSingingStats] = []
	var error: Error?
	private(set) var fetchCount = 0

	func fetchTrackSingingStats() async throws -> [TrackSingingStats] {
		fetchCount += 1
		if let error { throw error }
		return stats
	}
}

private struct StubError: Error {}

@Suite("AfterSaveRecommendationViewModel")
@MainActor
struct AfterSaveRecommendationViewModelTests {

	private let calendar: Calendar = {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
		return calendar
	}()

	private var now: Date {
		calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 22))!
	}

	private func daysAgo(_ days: Int) -> Date {
		calendar.date(byAdding: .day, value: -days, to: now)!
	}

	private func stats(_ name: String, intent: Intent = .emo, daysAgo days: Int, bestScore: Double? = 90) -> TrackSingingStats {
		TrackSingingStats(
			trackId: UUID(),
			spotifyTrackId: nil,
			userEnteredName: name,
			latestIntent: intent,
			lastPerformedAt: daysAgo(days),
			bestScore: bestScore,
			sessionCount: 1
		)
	}

	private func saved(intent: Intent = .emo, isNew: Bool = true) -> SavedRecording {
		SavedRecording(
			sessionId: UUID(),
			trackId: UUID(),
			trackTitle: "Pretender",
			intent: intent,
			score: 91.25,
			isNewRecording: isNew
		)
	}

	private func makeViewModel(_ repository: any TrackStatsRepositoryProtocol) -> AfterSaveRecommendationViewModel {
		let vm = AfterSaveRecommendationViewModel(trackStatsRepository: repository)
		vm.now = { now }
		vm.calendar = calendar
		return vm
	}

	@Test("候補があれば、保存した記録と上位 2 件を返す")
	func preparesTopTwo() async throws {
		let repository = StubTrackStatsRepository()
		repository.stats = [
			stats("1位", daysAgo: 60, bestScore: 100),
			stats("2位", daysAgo: 60, bestScore: 95),
			stats("3位", daysAgo: 60, bestScore: 80),
		]
		let vm = makeViewModel(repository)
		let savedRecording = saved()

		let content = try #require(await vm.prepare(for: savedRecording))

		#expect(content.saved == savedRecording)
		#expect(content.recommendations.map { $0.stats.userEnteredName } == ["1位", "2位"])
	}

	@Test("保存した記録の気分で候補を選ぶ")
	func usesSavedIntent() async throws {
		let repository = StubTrackStatsRepository()
		repository.stats = [
			stats("Emo", intent: .emo, daysAgo: 30),
			stats("Shout", intent: .shout, daysAgo: 30),
		]
		let vm = makeViewModel(repository)

		let content = try #require(await vm.prepare(for: saved(intent: .shout)))

		#expect(content.recommendations.map { $0.stats.userEnteredName } == ["Shout"])
	}

	@Test("編集して更新したときは、読み込まずに nil を返す")
	func skipsEdit() async {
		let repository = StubTrackStatsRepository()
		repository.stats = [stats("候補", daysAgo: 30)]
		let vm = makeViewModel(repository)

		#expect(await vm.prepare(for: saved(isNew: false)) == nil)
		#expect(repository.fetchCount == 0)
	}

	@Test("候補が 0 件のときは nil を返す")
	func skipsWhenNoCandidates() async {
		let repository = StubTrackStatsRepository()
		repository.stats = [stats("今日歌った曲", daysAgo: 0)]
		let vm = makeViewModel(repository)

		#expect(await vm.prepare(for: saved()) == nil)
	}

	@Test("読み込みに失敗したときは nil を返す")
	func skipsOnError() async {
		let repository = StubTrackStatsRepository()
		repository.error = StubError()
		let vm = makeViewModel(repository)

		#expect(await vm.prepare(for: saved()) == nil)
	}

	@Test("後から呼ばれた prepare に追い越された古い呼び出しは nil を返す")
	func staleCallReturnsNil() async throws {
		let repository = SuspendingTrackStatsRepository()
		repository.stats = [stats("候補", daysAgo: 30)]
		let vm = makeViewModel(repository)

		let first = Task { await vm.prepare(for: saved()) }
		await repository.waitUntilFetchStarted()
		// 1 回目の読み込み中に 2 回目が始まる（編集の保存なので、こちらは読み込まずに終わる）
		_ = await vm.prepare(for: saved(isNew: false))
		repository.resume()

		#expect(await first.value == nil)
	}
}

/// 1 回目の読み込みを、テストが `resume()` するまで止めておく。
@MainActor
private final class SuspendingTrackStatsRepository: TrackStatsRepositoryProtocol {
	var stats: [TrackSingingStats] = []
	private var fetchContinuation: CheckedContinuation<Void, Never>?
	private var startedContinuation: CheckedContinuation<Void, Never>?
	private var hasStarted = false

	func fetchTrackSingingStats() async throws -> [TrackSingingStats] {
		hasStarted = true
		startedContinuation?.resume()
		startedContinuation = nil
		await withCheckedContinuation { fetchContinuation = $0 }
		return stats
	}

	func waitUntilFetchStarted() async {
		guard !hasStarted else { return }
		await withCheckedContinuation { startedContinuation = $0 }
	}

	func resume() {
		fetchContinuation?.resume()
		fetchContinuation = nil
	}
}
