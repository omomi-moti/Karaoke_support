import Foundation
import Testing

@testable import Karaoke_support

@Suite("NextTrackRecommender")
struct NextTrackRecommenderTests {

	private let calendar: Calendar = {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
		return calendar
	}()

	/// 2026/10/24 22:00（ひとカラの後半）
	private var now: Date { date(2026, 10, 24, 22) }

	private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
		calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
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

	private func recommendedNames(_ stats: [TrackSingingStats], mood: Intent = .emo, limit: Int = 10) -> [String] {
		NextTrackRecommender
			.recommend(from: stats, mood: mood, now: now, calendar: calendar, limit: limit)
			.map { $0.stats.userEnteredName ?? "" }
	}

	// MARK: 外す曲

	@Test("今日歌った曲は候補に出ない")
	func excludesTracksSungToday() {
		let names = recommendedNames([
			stats("今日", lastPerformedAt: date(2026, 10, 24, 20), bestScore: 95),
			stats("昨日", lastPerformedAt: daysAgo(1), bestScore: 80),
		])
		#expect(names == ["昨日"])
	}

	@Test("1日の区切りは朝5時。日付をまたいでも同じ日とみなす")
	func dayBoundaryIsFiveAM() {
		let lateNight = date(2026, 10, 25, 1)  // 前日 23:30 から続くひとカラ
		let tracks = [
			stats("前日23時半", lastPerformedAt: date(2026, 10, 24, 23, 30), bestScore: 90),
			stats("当日4時59分", lastPerformedAt: date(2026, 10, 24, 4, 59), bestScore: 90),
			stats("当日5時", lastPerformedAt: date(2026, 10, 24, 5), bestScore: 90),
		]
		let names = NextTrackRecommender
			.recommend(from: tracks, mood: .emo, now: lateNight, calendar: calendar, limit: 10)
			.map { $0.stats.userEnteredName ?? "" }
		// 4:59 は前の日の扱いなので出る。5:00 以降は 1:00 と同じ日なので出ない
		#expect(names == ["当日4時59分"])
	}

	@Test("最新の記録の気分が今の気分と違う曲は出ない")
	func excludesOtherMoods() {
		let names = recommendedNames([
			stats("Shout", intent: .shout, lastPerformedAt: daysAgo(30), bestScore: 95),
			stats("Emo", intent: .emo, lastPerformedAt: daysAgo(30), bestScore: 80),
		])
		#expect(names == ["Emo"])
	}

	// MARK: 並び

	@Test("90点・2週間前の曲が、80点・2ヶ月前の曲より上に出る")
	func higherScoreBeatsLongerAbsence() {
		let names = recommendedNames([
			stats("80点・2ヶ月前", lastPerformedAt: daysAgo(60), bestScore: 80),
			stats("90点・2週間前", lastPerformedAt: daysAgo(14), bestScore: 90),
		])
		#expect(names == ["90点・2週間前", "80点・2ヶ月前"])
	}

	@Test("85点・2ヶ月前の曲が、90点・昨日の曲より上に出る")
	func longAbsenceBeatsSmallScoreGap() {
		let names = recommendedNames([
			stats("90点・昨日", lastPerformedAt: daysAgo(1), bestScore: 90),
			stats("85点・2ヶ月前", lastPerformedAt: daysAgo(60), bestScore: 85),
		])
		#expect(names == ["85点・2ヶ月前", "90点・昨日"])
	}

	@Test("スコアが同じなら最後に歌った日が古い順、それも同じなら曲の ID 順")
	func tieBreaks() {
		let older = daysAgo(90)
		let newer = daysAgo(70)  // どちらも 60 日を超えているので久しぶり度は同じ
		let idA = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
		let idB = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
		let names = recommendedNames([
			stats("新しい", lastPerformedAt: newer, bestScore: 90),
			stats("古いB", lastPerformedAt: older, bestScore: 90, trackId: idB),
			stats("古いA", lastPerformedAt: older, bestScore: 90, trackId: idA),
		])
		#expect(names == ["古いA", "古いB", "新しい"])
	}

	@Test("同じ入力なら、渡す順番によらず同じ順番が返る")
	func deterministicOrder() {
		let tracks = [
			stats("A", lastPerformedAt: daysAgo(3), bestScore: 88),
			stats("B", lastPerformedAt: daysAgo(40), bestScore: nil),
			stats("C", lastPerformedAt: daysAgo(14), bestScore: 92.5),
			stats("D", lastPerformedAt: daysAgo(120), bestScore: 75),
			stats("E", lastPerformedAt: daysAgo(40), bestScore: nil),
		]
		let expected = recommendedNames(tracks)
		#expect(recommendedNames(tracks.reversed()) == expected)
		#expect(recommendedNames([tracks[2], tracks[4], tracks[0], tracks[3], tracks[1]]) == expected)
	}

	@Test("上位 limit 件だけ返す")
	func respectsLimit() {
		let names = recommendedNames(
			[
				stats("1位", lastPerformedAt: daysAgo(60), bestScore: 100),
				stats("2位", lastPerformedAt: daysAgo(60), bestScore: 90),
				stats("3位", lastPerformedAt: daysAgo(60), bestScore: 80),
			],
			limit: 2
		)
		#expect(names == ["1位", "2位"])
	}

	// MARK: 各項

	@Test("点数なしの曲の scoreNorm は 0.5 になる")
	func missingScoreNormIsHalf() {
		#expect(NextTrackRecommender.scoreNorm(bestScore: nil) == 0.5)
		#expect(NextTrackRecommender.scoreNorm(bestScore: 85) == 0.5)
	}

	@Test("scoreNorm は 70 点以下で 0、100 点で 1")
	func scoreNormIsClamped() {
		#expect(NextTrackRecommender.scoreNorm(bestScore: 0) == 0)
		#expect(NextTrackRecommender.scoreNorm(bestScore: 70) == 0)
		#expect(NextTrackRecommender.scoreNorm(bestScore: 100) == 1)
	}

	@Test("60日以上歌っていない曲の recency は 1 で頭打ちになる")
	func recencyIsCapped() {
		#expect(NextTrackRecommender.recency(daysSinceLastSung: 30) == 0.5)
		#expect(NextTrackRecommender.recency(daysSinceLastSung: 60) == 1)
		#expect(NextTrackRecommender.recency(daysSinceLastSung: 365) == 1)
	}

	@Test("最後に歌ってからの日数を候補に入れる")
	func reportsDaysSinceLastSung() {
		let result = NextTrackRecommender.recommend(
			from: [stats("2週間前", lastPerformedAt: daysAgo(14), bestScore: 90)],
			mood: .emo,
			now: now,
			calendar: calendar,
			limit: 2
		)
		#expect(result.map(\.daysSinceLastSung) == [14])
	}

	// MARK: また歌いたい（ハート・#124）

	@Test("ハート付きの曲は、点数が高く久しぶりなハートなしの曲より上に出る")
	func wantAgainRanksAboveEverythingElse() {
		let names = recommendedNames([
			stats("ハートなし・100点・半年ぶり", lastPerformedAt: daysAgo(180), bestScore: 100),
			stats("ハート付き・70点・昨日", lastPerformedAt: daysAgo(1), bestScore: 70, wantAgain: true),
		])
		#expect(names == ["ハート付き・70点・昨日", "ハートなし・100点・半年ぶり"])
	}

	@Test("ハート付き同士は、今までどおり点数と久しぶり度で並ぶ")
	func wantAgainTracksKeepTheirOrder() {
		let names = recommendedNames([
			stats("ハート・80点", lastPerformedAt: daysAgo(14), bestScore: 80, wantAgain: true),
			stats("ハート・95点", lastPerformedAt: daysAgo(14), bestScore: 95, wantAgain: true),
		])
		#expect(names == ["ハート・95点", "ハート・80点"])
	}

	@Test("ハート付きでも、気分が違う曲は出ない")
	func wantAgainDoesNotCrossMoods() {
		let names = recommendedNames([
			stats("Shoutのハート", intent: .shout, lastPerformedAt: daysAgo(10), bestScore: 95, wantAgain: true),
			stats("Emoのハートなし", intent: .emo, lastPerformedAt: daysAgo(10), bestScore: 80),
		], mood: .emo)
		#expect(names == ["Emoのハートなし"])
	}

	@Test("ハートの項は 3.0 で、点数と久しぶり度を足した最大値 2.5 より大きい")
	func wantAgainWeightExceedsOtherTerms() {
		let withHeart = NextTrackRecommender.score(bestScore: 70, daysSinceLastSung: 1, wantAgain: true)
		let withoutHeart = NextTrackRecommender.score(bestScore: 70, daysSinceLastSung: 1, wantAgain: false)
		#expect(withHeart - withoutHeart == 3.0)
		#expect(NextTrackRecommender.scoreWeight + NextTrackRecommender.recencyWeight < NextTrackRecommender.wantAgainWeight)
	}
}
