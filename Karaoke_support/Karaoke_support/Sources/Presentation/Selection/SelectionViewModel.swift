import Foundation
import Observation

/// 選曲画面（#126）。曲ごとの集計を読み、選んでいる気分で「また歌いたい」と「今の気分に合う曲」に分ける。
///
/// 気分を切り替えても読み直さず、読んだ集計から並べ直す。
@MainActor
@Observable
final class SelectionViewModel {
	private let trackStatsRepository: any TrackStatsRepositoryProtocol

	/// ``load()`` を呼ぶたびに増やす。`await` の後もこの値と一致するときだけ結果を使う。
	@ObservationIgnored private var loadGeneration: UInt = 0

	/// 今の時刻とカレンダー。テストでは固定する。
	@ObservationIgnored var now: () -> Date = Date.init
	@ObservationIgnored var calendar: Calendar = .current

	private(set) var stats: [TrackSingingStats] = []
	private(set) var hasLoaded = false
	private(set) var isLoading = false
	private(set) var loadErrorMessage: String?
	/// 選んでいる気分。読み込むたびに、直前の記録の気分にする。
	var mood: Intent = .emo

	init(trackStatsRepository: any TrackStatsRepositoryProtocol) {
		self.trackStatsRepository = trackStatsRepository
	}

	var shouldShowBlockingLoad: Bool { isLoading && !hasLoaded }

	var hasSingingData: Bool { !stats.isEmpty }

	var sections: TrackSelectionSections {
		NextTrackRecommender.sections(from: stats, mood: mood, now: now(), calendar: calendar)
	}

	/// Practice のチップを選んでいるときは、「練習中の曲」と「歌い切れなかった曲」を出す（#131）。
	var isShowingPractice: Bool { mood == .practice }

	var practice: TrackPracticeSections {
		NextTrackRecommender.practice(from: stats, now: now(), calendar: calendar)
	}

	func load() async {
		loadGeneration += 1
		let attempt = loadGeneration
		isLoading = true
		loadErrorMessage = nil
		do {
			let fetched = try await trackStatsRepository.fetchTrackSingingStats()
			guard attempt == loadGeneration else { return }
			stats = fetched
			if let latest = fetched.max(by: { $0.lastPerformedAt < $1.lastPerformedAt }) {
				mood = latest.latestIntent
			}
			hasLoaded = true
		} catch {
			guard attempt == loadGeneration else { return }
			loadErrorMessage = "曲を読み込めませんでした。もう一度お試しください"
		}
		isLoading = false
	}
}
