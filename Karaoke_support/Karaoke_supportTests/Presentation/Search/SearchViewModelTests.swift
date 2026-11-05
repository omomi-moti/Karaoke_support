import Foundation
import Testing

@testable import Karaoke_support

@MainActor
private final class StubTrackRepository: TrackRepositoryProtocol {
	func searchLocal(query: String) async throws -> [Track] { [Track(userEnteredName: query)] }

	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?) async throws -> Track {
		Track(userEnteredName: userEnteredName ?? "曲")
	}

	func incrementSingCount(trackId: UUID) async throws {}
}

@MainActor
private final class StubTrackStatsRepository: TrackStatsRepositoryProtocol {
	var stats: [TrackSingingStats] = []
	var error: Error?
	/// `true` にすると、次の読み込みを ``resumeHeldFetch()`` まで止めておく。
	var holdsNextFetch = false
	private(set) var heldContinuation: CheckedContinuation<Void, Never>?

	func fetchTrackSingingStats() async throws -> [TrackSingingStats] {
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

@Suite("SearchViewModel")
@MainActor
struct SearchViewModelTests {

	private let statsRepository = StubTrackStatsRepository()

	private let calendar: Calendar = {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
		return calendar
	}()

	private var now: Date {
		calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 22))!
	}

	private func stats(_ name: String, daysAgo days: Int) -> TrackSingingStats {
		TrackSingingStats(
			trackId: UUID(),
			spotifyTrackId: nil,
			userEnteredName: name,
			latestIntent: .emo,
			lastPerformedAt: calendar.date(byAdding: .day, value: -days, to: now)!,
			bestScore: nil,
			sessionCount: 1
		)
	}

	private func makeViewModel() -> SearchViewModel {
		let vm = SearchViewModel(trackRepository: StubTrackRepository(), trackStatsRepository: statsRepository)
		vm.now = { now }
		vm.calendar = calendar
		return vm
	}

	@Test("最近歌った曲は、最後に歌った日が新しい順に 5 件まで")
	func recentTracksAreNewestFirstUpToFive() async {
		statsRepository.stats = [
			stats("6日前", daysAgo: 6),
			stats("1日前", daysAgo: 1),
			stats("4日前", daysAgo: 4),
			stats("2日前", daysAgo: 2),
			stats("5日前", daysAgo: 5),
			stats("3日前", daysAgo: 3),
		]
		let vm = makeViewModel()

		await vm.loadRecent()

		#expect(vm.recentTracks.map(\.title) == ["1日前", "2日前", "3日前", "4日前", "5日前"])
		#expect(vm.recentErrorMessage == nil)
	}

	@Test("読み込みに失敗したら、再試行できるように知らせる。次に成功したら知らせを消す")
	func recentLoadFailureShowsMessage() async {
		statsRepository.error = StubError()
		let vm = makeViewModel()

		await vm.loadRecent()
		#expect(vm.recentErrorMessage != nil)

		statsRepository.error = nil
		statsRepository.stats = [stats("曲", daysAgo: 1)]
		await vm.loadRecent()
		#expect(vm.recentErrorMessage == nil)
		#expect(vm.recentTracks.map(\.title) == ["曲"])
	}

	@Test("先に始まった読み込みが後から終わっても、新しい結果を上書きしない")
	func staleRecentLoadDoesNotOverwrite() async {
		let vm = makeViewModel()
		statsRepository.stats = [stats("古い", daysAgo: 1)]
		statsRepository.holdsNextFetch = true
		let first = Task { await vm.loadRecent() }
		while statsRepository.heldContinuation == nil { await Task.yield() }

		statsRepository.stats = [stats("新しい", daysAgo: 1)]
		await vm.loadRecent()
		statsRepository.resumeHeldFetch()
		await first.value

		#expect(vm.recentTracks.map(\.title) == ["新しい"])
	}

	@Test("打ち終わりを待っている間は検索中とし、前の結果を消さない")
	func searchingWhileDebouncingKeepsPreviousResult() async {
		let vm = makeViewModel()

		let first = Task { await vm.search(query: "a") }
		for _ in 0..<10 where !vm.isSearching { await Task.yield() }
		#expect(vm.isSearching)
		#expect(vm.result.isEmpty)
		await first.value
		#expect(!vm.isSearching)
		#expect(vm.result.map(\.title) == ["a"])

		let second = Task { await vm.search(query: "ab") }
		for _ in 0..<10 where !vm.isSearching { await Task.yield() }
		#expect(vm.isSearching)
		#expect(vm.result.map(\.title) == ["a"])
		await second.value
		#expect(!vm.isSearching)
		#expect(vm.result.map(\.title) == ["ab"])
	}
}
