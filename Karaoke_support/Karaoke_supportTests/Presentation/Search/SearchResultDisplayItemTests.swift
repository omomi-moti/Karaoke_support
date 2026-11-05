import Foundation
import SwiftData
import Testing

@testable import Karaoke_support

@Suite("SearchResultDisplayItem")
@MainActor
struct SearchResultDisplayItemTests {

	private let calendar: Calendar = {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
		return calendar
	}()

	private var now: Date {
		calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 22))!
	}

	private func makeContext() throws -> ModelContext {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		return ModelContext(container)
	}

	private func date(daysAgo days: Int) -> Date {
		calendar.date(byAdding: .day, value: -days, to: now)!
	}

	@Test("検索結果の曲は、一番新しい記録の日・気分・ハートを出す")
	func mapsTrackFromLatestSession() throws {
		let context = try makeContext()
		let track = Track(userEnteredName: "アイドル")
		context.insert(track)
		context.insert(SingingSession(track: track, intent: .shout, performedAt: date(daysAgo: 30), score: 95, wantAgain: false))
		context.insert(SingingSession(track: track, intent: .emo, performedAt: date(daysAgo: 5), score: nil, wantAgain: true))
		context.insert(SingingSession(track: track, intent: .practice, performedAt: date(daysAgo: 12), score: 88))

		let item = SearchResultDisplayItem(track: track, now: now, calendar: calendar)

		#expect(item.id == track.id)
		#expect(item.title == "アイドル")
		#expect(item.history == "3回歌った ・ 前回は5日前")
		#expect(item.latestIntent == .emo)
		#expect(item.isWantAgain)
		#expect(item.subtitle == "3回歌った ・ 前回は5日前 ・ Emo")
	}

	@Test("今日歌った曲は「今日歌った」と出す")
	func mapsTrackSungToday() throws {
		let context = try makeContext()
		let track = Track(userEnteredName: "曲")
		context.insert(track)
		context.insert(SingingSession(track: track, intent: .emo, performedAt: date(daysAgo: 0), score: nil))

		#expect(SearchResultDisplayItem(track: track, now: now, calendar: calendar).history == "1回歌った ・ 今日歌った")
	}

	@Test("記録が 1 件もない曲は、回数だけを出し、気分とハートは出さない")
	func mapsTrackWithoutSessions() throws {
		let context = try makeContext()
		let track = Track(userEnteredName: "曲")
		context.insert(track)

		let item = SearchResultDisplayItem(track: track, now: now, calendar: calendar)

		#expect(item.history == "0回歌った")
		#expect(item.latestIntent == nil)
		#expect(!item.isWantAgain)
		#expect(item.subtitle == "0回歌った")
	}

	@Test("最近の曲は、曲ごとの集計からそのまま写す")
	func mapsStats() {
		let trackId = UUID()
		let stats = TrackSingingStats(
			trackId: trackId,
			spotifyTrackId: nil,
			userEnteredName: "白日",
			latestIntent: .practice,
			lastPerformedAt: date(daysAgo: 14),
			bestScore: 90.5,
			sessionCount: 4,
			latestWantAgain: true
		)

		let item = SearchResultDisplayItem(stats: stats, now: now, calendar: calendar)

		#expect(item.id == trackId)
		#expect(item.userEnteredName == "白日")
		#expect(item.title == "白日")
		#expect(item.history == "4回歌った ・ 前回は2週間前")
		#expect(item.latestIntent == .practice)
		#expect(item.subtitle == "4回歌った ・ 前回は2週間前 ・ Practice")
		#expect(item.isWantAgain)
	}
}
