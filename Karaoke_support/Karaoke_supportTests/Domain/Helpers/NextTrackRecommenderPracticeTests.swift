import Foundation
import Testing

@testable import Karaoke_support

@Suite("NextTrackRecommender の Practice（練習中の曲・歌い切れなかった曲）")
struct NextTrackRecommenderPracticeTests {

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

	private func practice(_ stats: [TrackSingingStats]) -> TrackPracticeSections {
		NextTrackRecommender.practice(from: stats, now: now, calendar: calendar)
	}

	private func names(_ recommendations: [TrackRecommendation]) -> [String] {
		recommendations.map { $0.stats.userEnteredName ?? "" }
	}

	@Test("Practice で歌い切れた曲は「練習中の曲」、歌い切れなかった曲は気分に関係なく「歌い切れなかった曲」")
	func splitsPracticingAndUnfinished() {
		let result = practice([
			stats("Practice", intent: .practice, lastPerformedAt: daysAgo(10), bestScore: 80),
			stats("Emo・歌い切れず", lastPerformedAt: daysAgo(5), bestScore: nil, isCompleted: false),
			stats("Practice・歌い切れず", intent: .practice, lastPerformedAt: daysAgo(3), bestScore: nil, isCompleted: false),
			stats("Emo・歌い切れた", lastPerformedAt: daysAgo(20), bestScore: 90),
		])
		#expect(names(result.practicing) == ["Practice"])
		#expect(names(result.unfinished) == ["Emo・歌い切れず", "Practice・歌い切れず"])
	}

	@Test("Practice 以外の気分で歌い切った曲は、挑戦中に入らない")
	func completedInOtherMoodIsNotChallenging() {
		let shout = stats("Shout・歌い切れた", intent: .shout, lastPerformedAt: daysAgo(3), bestScore: 70)
		#expect(!shout.isChallenging)
		#expect(practice([shout]).isEmpty)
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

	@Test("今日歌った曲も消さずに、それぞれのいちばん下に出す")
	func keepsTracksSungTodayAtBottom() {
		let result = practice([
			stats("今日・ハート", intent: .practice, lastPerformedAt: now, bestScore: 80, wantAgain: true),
			stats("昨日", intent: .practice, lastPerformedAt: daysAgo(1), bestScore: 80),
			stats("今日・歌い切れず", lastPerformedAt: now, bestScore: nil, isCompleted: false),
			stats("1週間前・歌い切れず", lastPerformedAt: daysAgo(7), bestScore: nil, isCompleted: false),
		])
		#expect(names(result.practicing) == ["昨日", "今日・ハート"])
		#expect(names(result.unfinished) == ["1週間前・歌い切れず", "今日・歌い切れず"])
		#expect(result.practicing.last?.daysSinceLastSung == 0)
	}

	@Test("今日歌っていない曲の中では、ハート付きが日数より先に来る")
	func wantAgainComesFirst() {
		let result = practice([
			stats("1ヶ月前", intent: .practice, lastPerformedAt: daysAgo(30), bestScore: 70),
			stats("2日前・ハート", intent: .practice, lastPerformedAt: daysAgo(2), bestScore: 90, wantAgain: true),
			stats("歌い切れず・1ヶ月前", lastPerformedAt: daysAgo(30), bestScore: nil, isCompleted: false),
			stats("歌い切れず・2日前・ハート", lastPerformedAt: daysAgo(2), bestScore: nil, wantAgain: true, isCompleted: false),
		])
		#expect(names(result.practicing) == ["2日前・ハート", "1ヶ月前"])
		#expect(names(result.unfinished) == ["歌い切れず・2日前・ハート", "歌い切れず・1ヶ月前"])
	}

	@Test("日数が同じなら最高点が低い順で、点数がない曲を一番低いとする")
	func tieBreaksByLowerBestScore() {
		let result = practice([
			stats("90点", intent: .practice, lastPerformedAt: daysAgo(7), bestScore: 90),
			stats("点数なし", intent: .practice, lastPerformedAt: daysAgo(7), bestScore: nil),
			stats("75点", intent: .practice, lastPerformedAt: daysAgo(7), bestScore: 75),
		])
		#expect(names(result.practicing) == ["点数なし", "75点", "90点"])
	}

	@Test("同じ入力なら、渡す順番によらず同じ順番が返る")
	func isStableRegardlessOfInputOrder() {
		let all = [
			stats("A", intent: .practice, lastPerformedAt: daysAgo(7), bestScore: 80),
			stats("B", intent: .practice, lastPerformedAt: daysAgo(7), bestScore: 80),
			stats("C", lastPerformedAt: daysAgo(2), bestScore: nil, isCompleted: false),
		]
		#expect(practice(all) == practice(all.reversed()))
	}
}
