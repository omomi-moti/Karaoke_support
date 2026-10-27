import Foundation
import Testing

@testable import Karaoke_support

@Suite("NextTrackRecommender の選曲画面のセクション")
struct NextTrackRecommenderSectionsTests {

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
			latestWantAgain: wantAgain
		)
	}

	private func sections(_ stats: [TrackSingingStats], mood: Intent = .emo) -> TrackSelectionSections {
		NextTrackRecommender.sections(from: stats, mood: mood, now: now, calendar: calendar)
	}

	private func names(_ recommendations: [TrackRecommendation]) -> [String] {
		recommendations.map { $0.stats.userEnteredName ?? "" }
	}

	@Test("ハート付きの曲は、気分が違っても「また歌いたい」に出る")
	func wantAgainIncludesOtherMoods() {
		let result = sections([
			stats("Shout のハート", intent: .shout, lastPerformedAt: daysAgo(3), bestScore: 90, wantAgain: true),
		])
		#expect(names(result.wantAgain) == ["Shout のハート"])
		#expect(result.moodMatched.isEmpty)
	}

	@Test("「また歌いたい」は同じ気分の曲が上で、その中はスコア順")
	func wantAgainPutsSameMoodFirst() {
		let result = sections([
			stats("Shout・95点", intent: .shout, lastPerformedAt: daysAgo(30), bestScore: 95, wantAgain: true),
			stats("Emo・80点", lastPerformedAt: daysAgo(3), bestScore: 80, wantAgain: true),
			stats("Emo・95点", lastPerformedAt: daysAgo(3), bestScore: 95, wantAgain: true),
		])
		#expect(names(result.wantAgain) == ["Emo・95点", "Emo・80点", "Shout・95点"])
	}

	@Test("「今の気分に合う曲」には、ハートなしで同じ気分の曲だけがスコア順に出る")
	func moodMatchedHasSameMoodWithoutHeart() {
		let result = sections([
			stats("Emo・80点", lastPerformedAt: daysAgo(3), bestScore: 80),
			stats("Shout・95点", intent: .shout, lastPerformedAt: daysAgo(3), bestScore: 95),
			stats("Emo・95点", lastPerformedAt: daysAgo(3), bestScore: 95),
		])
		#expect(names(result.moodMatched) == ["Emo・95点", "Emo・80点"])
		#expect(result.wantAgain.isEmpty)
	}

	@Test("ハート付きの曲は「今の気分に合う曲」に重ねて出ない")
	func wantAgainIsNotRepeatedInMoodMatched() {
		let result = sections([
			stats("ハート", lastPerformedAt: daysAgo(3), bestScore: 90, wantAgain: true),
			stats("ハートなし", lastPerformedAt: daysAgo(3), bestScore: 90),
		])
		#expect(names(result.wantAgain) == ["ハート"])
		#expect(names(result.moodMatched) == ["ハートなし"])
	}

	@Test("今日歌った曲は、どちらのセクションにも出ない")
	func excludesTracksSungToday() {
		let result = sections([
			stats("今日・ハート", lastPerformedAt: now, bestScore: 95, wantAgain: true),
			stats("今日・ハートなし", lastPerformedAt: now, bestScore: 95),
			stats("昨日", lastPerformedAt: daysAgo(1), bestScore: 80),
		])
		#expect(result.wantAgain.isEmpty)
		#expect(names(result.moodMatched) == ["昨日"])
	}

	@Test("件数を絞らず、候補を全部返す")
	func returnsAllCandidates() {
		let all = (1...12).map { stats("曲\($0)", lastPerformedAt: daysAgo($0), bestScore: 80, wantAgain: $0.isMultiple(of: 3)) }
		let result = sections(all)
		#expect(result.wantAgain.count == 4)
		#expect(result.moodMatched.count == 8)
	}

	@Test("同じ入力なら、渡す順番によらず同じ結果を返す")
	func isStableRegardlessOfInputOrder() {
		let all = [
			stats("A", lastPerformedAt: daysAgo(5), bestScore: 85, wantAgain: true),
			stats("B", intent: .shout, lastPerformedAt: daysAgo(5), bestScore: 85, wantAgain: true),
			stats("C", lastPerformedAt: daysAgo(5), bestScore: 85),
			stats("D", lastPerformedAt: daysAgo(5), bestScore: 85),
		]
		#expect(sections(all) == sections(all.reversed()))
	}

	@Test("候補がなければ isEmpty になる")
	func isEmptyWithoutCandidates() {
		#expect(sections([]).isEmpty)
		#expect(sections([stats("Shout", intent: .shout, lastPerformedAt: daysAgo(3), bestScore: 90)]).isEmpty)
		#expect(!sections([stats("Emo", lastPerformedAt: daysAgo(3), bestScore: 90)]).isEmpty)
	}
}
