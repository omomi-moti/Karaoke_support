import Foundation
import Testing

@testable import Karaoke_support

@MainActor
private final class StubTrackStatsRepository: TrackStatsRepositoryProtocol {
	var stats: [TrackSingingStats] = []
	var error: Error?
	private(set) var fetchCount = 0
	/// `true` にすると、次の読み込みを ``resumeHeldFetch()`` まで止めておく。
	var holdsNextFetch = false
	private(set) var heldContinuation: CheckedContinuation<Void, Never>?

	func fetchTrackSingingStats() async throws -> [TrackSingingStats] {
		fetchCount += 1
		let stats = stats
		let error = error
		if holdsNextFetch {
			holdsNextFetch = false
			await withCheckedContinuation { heldContinuation = $0 }
		}
		if let error { throw error }
		return stats
	}

	func resumeHeldFetch() {
		heldContinuation?.resume()
		heldContinuation = nil
	}
}

private struct StubError: Error {}

@Suite("SelectionViewModel")
@MainActor
struct SelectionViewModelTests {

	private let repository = StubTrackStatsRepository()

	private let calendar: Calendar = {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
		return calendar
	}()

	private var now: Date {
		calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 22))!
	}

	private func stats(_ name: String, intent: Intent = .emo, daysAgo days: Int, wantAgain: Bool = false) -> TrackSingingStats {
		TrackSingingStats(
			trackId: UUID(),
			spotifyTrackId: nil,
			userEnteredName: name,
			latestIntent: intent,
			lastPerformedAt: calendar.date(byAdding: .day, value: -days, to: now)!,
			bestScore: 90,
			sessionCount: 1,
			latestWantAgain: wantAgain
		)
	}

	private func makeViewModel() -> SelectionViewModel {
		let vm = SelectionViewModel(trackStatsRepository: repository)
		vm.now = { now }
		vm.calendar = calendar
		return vm
	}

	private func names(_ recommendations: [TrackRecommendation]) -> [String] {
		recommendations.map { $0.stats.userEnteredName ?? "" }
	}

	@Test("読み込むと、気分は直前の記録の気分になる")
	func moodStartsFromLatestRecord() async {
		repository.stats = [
			stats("前の Emo", intent: .emo, daysAgo: 5),
			stats("直前の Shout", intent: .shout, daysAgo: 1),
		]
		let vm = makeViewModel()

		await vm.load()

		#expect(vm.mood == .shout)
		#expect(names(vm.sections.moodMatched) == ["直前の Shout"])
	}

	@Test("気分を切り替えると、読み直さずに並び替わる")
	func switchingMoodDoesNotRefetch() async {
		repository.stats = [
			stats("Emo", intent: .emo, daysAgo: 5),
			stats("Shout", intent: .shout, daysAgo: 1),
		]
		let vm = makeViewModel()
		await vm.load()

		vm.mood = .emo

		#expect(names(vm.sections.moodMatched) == ["Emo"])
		#expect(repository.fetchCount == 1)
	}

	@Test("読み込みに失敗するとエラーになり、再試行で戻る")
	func retryAfterFailure() async {
		repository.error = StubError()
		let vm = makeViewModel()

		await vm.load()
		#expect(vm.loadErrorMessage != nil)
		#expect(!vm.hasLoaded)

		repository.error = nil
		repository.stats = [stats("Emo", daysAgo: 3)]
		await vm.load()

		#expect(vm.loadErrorMessage == nil)
		#expect(vm.hasLoaded)
		#expect(names(vm.sections.moodMatched) == ["Emo"])
	}

	@Test("記録がまったくないと、hasSingingData が false になる")
	func noRecords() async {
		let vm = makeViewModel()

		await vm.load()

		#expect(vm.hasLoaded)
		#expect(!vm.hasSingingData)
		#expect(vm.sections.isEmpty)
	}

	@Test("記録はあっても今日歌った曲だけなら、候補は 0 件になる")
	func noCandidatesWhenAllSungToday() async {
		repository.stats = [stats("今日", daysAgo: 0, wantAgain: true)]
		let vm = makeViewModel()

		await vm.load()

		#expect(vm.hasSingingData)
		#expect(vm.sections.isEmpty)
	}

	@Test("古い読み込みの結果で、新しい結果を上書きしない")
	func discardsStaleLoad() async {
		repository.stats = [stats("古い", daysAgo: 3)]
		repository.holdsNextFetch = true
		let vm = makeViewModel()

		let staleLoad = Task { await vm.load() }
		while repository.heldContinuation == nil {
			await Task.yield()
		}
		repository.stats = [stats("新しい", daysAgo: 3)]
		await vm.load()
		repository.resumeHeldFetch()
		await staleLoad.value

		#expect(names(vm.sections.moodMatched) == ["新しい"])
		#expect(!vm.isLoading)
	}
}
