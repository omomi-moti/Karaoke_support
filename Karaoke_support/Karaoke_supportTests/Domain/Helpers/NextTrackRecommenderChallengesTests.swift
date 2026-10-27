import Foundation
import Testing

@testable import Karaoke_support

@Suite("NextTrackRecommender の挑戦中の曲")
struct NextTrackRecommenderChallengesTests {

	private let calendar: Calendar = {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
		return calendar
	}()

	/// 2026/10/24 22:00（ひとカラの後半）
	private var now: Date {
		calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 22))!
	}

	private func daysAgo(_ days: Int) -> Date {
		calendar.date(byAdding: .day, value: -days, to: now)!
	}

	private func stats(
		_ name: String,
		intent: Intent = .emo,
		lastPerformedAt: Date,
		bestScore: Double?,
		wantAgain: Bool = false,
		isCompleted: Bool = true,
		trackId: UUID = UUID()
	) -> TrackSingingStats {
		TrackSingingStats(
			trackId: trackId,
			spotifyTrackId: nil,
			userEnteredName: name,
			latestIntent: intent,
			lastPerformedAt: lastPerformedAt,
			bestScore: bestScore,
			sessionCount: 1,
			latestWantAgain: wantAgain,
			latestIsCompleted: isCompleted
		)
	}

	private func challengeNames(_ stats: [TrackSingingStats]) -> [String] {
		NextTrackRecommender.challenges(from: stats, now: now, calendar: calendar).map { $0.stats.userEnteredName ?? "" }
	}

	@Test("最新の記録が Practice の曲と、歌い切れなかった曲が挑戦中になる")
	func challengesIncludePracticeAndUnfinished() {
		let names = challengeNames([
			stats("Practice", intent: .practice, lastPerformedAt: daysAgo(10), bestScore: 80),
			stats("Emo・歌い切れず", lastPerformedAt: daysAgo(5), bestScore: nil, isCompleted: false),
			stats("Practice・歌い切れず", intent: .practice, lastPerformedAt: daysAgo(3), bestScore: nil, isCompleted: false),
			stats("Emo・歌い切れた", lastPerformedAt: daysAgo(20), bestScore: 90),
		])
		#expect(names == ["Practice", "Emo・歌い切れず", "Practice・歌い切れず"])
	}

	@Test("Practice 以外の気分で歌い切った曲は、挑戦中に入らない")
	func completedInOtherMoodIsNotChallenging() {
		let shout = stats("Shout・歌い切れた", intent: .shout, lastPerformedAt: daysAgo(3), bestScore: 70)
		#expect(!shout.isChallenging)
		#expect(challengeNames([shout]).isEmpty)
	}

	@Test("挑戦中の曲は、Practice を含むどの気分の候補にも「また歌いたい」にも出ない")
	func challengesAreExcludedFromOtherCandidates() {
		let all = [
			stats("Practice・ハート", intent: .practice, lastPerformedAt: daysAgo(3), bestScore: 95, wantAgain: true),
			stats("Emo・歌い切れず・ハート", lastPerformedAt: daysAgo(3), bestScore: 95, wantAgain: true, isCompleted: false),
			stats("Emo", lastPerformedAt: daysAgo(3), bestScore: 80),
		]
		for mood in Intent.allCases {
			let sections = NextTrackRecommender.sections(from: all, mood: mood, now: now, calendar: calendar)
			#expect(sections.wantAgain.isEmpty)
			let recommended = NextTrackRecommender.recommend(from: all, mood: mood, now: now, calendar: calendar, limit: 10)
			#expect(recommended.allSatisfy { !$0.stats.isChallenging })
		}
	}

	@Test("今日歌った曲は、挑戦中にも出ない")
	func excludesTracksSungToday() {
		let names = challengeNames([
			stats("今日", intent: .practice, lastPerformedAt: now, bestScore: 80),
			stats("昨日", intent: .practice, lastPerformedAt: daysAgo(1), bestScore: 80),
		])
		#expect(names == ["昨日"])
	}

	@Test("日数が同じなら最高点が低い順で、点数がない曲を一番低いとする")
	func tieBreaksByLowerBestScore() {
		let names = challengeNames([
			stats("90点", intent: .practice, lastPerformedAt: daysAgo(7), bestScore: 90),
			stats("点数なし", lastPerformedAt: daysAgo(7), bestScore: nil, isCompleted: false),
			stats("75点", intent: .practice, lastPerformedAt: daysAgo(7), bestScore: 75),
		])
		#expect(names == ["点数なし", "75点", "90点"])
	}

	@Test("同じ入力なら、渡す順番によらず同じ順番が返る")
	func isStableRegardlessOfInputOrder() {
		let all = [
			stats("A", intent: .practice, lastPerformedAt: daysAgo(7), bestScore: 80),
			stats("B", intent: .practice, lastPerformedAt: daysAgo(7), bestScore: 80),
			stats("C", lastPerformedAt: daysAgo(2), bestScore: nil, isCompleted: false),
		]
		#expect(challengeNames(all) == challengeNames(all.reversed()))
	}
}
