import Foundation

/// 保存した直後に出す「次の 1 曲」の候補と、選曲画面に並べる候補を計算する。
///
/// 曲ごとの集計・今の気分・今の時刻だけから決める純粋関数で、同じ入力には必ず同じ順番を返す。
enum NextTrackRecommender {
	/// 点数を久しぶり度の 4 倍にする。「90 点・2 週間前」を「80 点・2ヶ月前」より上に、
	/// 「85 点・2ヶ月前」を「90 点・昨日」より上に出すため（2.3 倍より大きく 5.9 倍より小さい範囲）。
	/// 2 つを足しても最大 2.5 で、また歌いたいの項（3.0）より必ず小さくなる。
	static let scoreWeight = 2.0
	static let recencyWeight = 0.5
	/// 最新の記録にハートが付いた曲を、点数や久しぶり度にかかわらず、ハートなしの曲より上に出す（#124）。
	static let wantAgainWeight = 3.0

	/// この日数で久しぶり度が頭打ちになる。
	static let recencyCapDays = 60
	/// 点数なしの曲の scoreNorm。85 点の曲と同じ扱い。
	static let missingScoreNorm = 0.5
	/// 1 日の区切り（時）。日付をまたぐひとカラも同じ日とみなす。
	static let dayBoundaryHour = 5

	/// - Returns: 最新の記録の気分が `mood` と同じで、今日まだ歌っておらず、最新の記録で歌い切れた曲を、スコアの高い順に最大 `limit` 件。
	///   スコアが同じなら最後に歌った日が古い順、それも同じなら曲の ID 順。
	static func recommend(
		from stats: [TrackSingingStats],
		mood: Intent,
		now: Date,
		calendar: Calendar,
		limit: Int
	) -> [TrackRecommendation] {
		let found = candidates(from: stats, now: now, calendar: calendar)
			.filter { $0.stats.latestIntent == mood }
			.sorted(by: isRankedHigher)
		return Array(found.prefix(max(0, limit)))
	}

	/// - Returns: 今日まだ歌っておらず、最新の記録で歌い切れた曲を、選曲画面の 2 つのセクションに分けたもの。件数は絞らない。
	///   「また歌いたい」は `mood` と同じ気分の曲を上にし、その中と「今の気分に合う曲」は ``recommend(from:mood:now:calendar:limit:)`` と同じ順に並べる。
	static func sections(
		from stats: [TrackSingingStats],
		mood: Intent,
		now: Date,
		calendar: Calendar
	) -> TrackSelectionSections {
		let found = candidates(from: stats, now: now, calendar: calendar)
		let wantAgain = found
			.filter(\.stats.latestWantAgain)
			.sorted { a, b in
				let aMatchesMood = a.stats.latestIntent == mood
				let bMatchesMood = b.stats.latestIntent == mood
				if aMatchesMood != bMatchesMood { return aMatchesMood }
				return isRankedHigher(a, b)
			}
		let moodMatched = found
			.filter { !$0.stats.latestWantAgain && $0.stats.latestIntent == mood }
			.sorted(by: isRankedHigher)
		return TrackSelectionSections(wantAgain: wantAgain, moodMatched: moodMatched)
	}

	static func score(bestScore: Double?, daysSinceLastSung: Int, wantAgain: Bool) -> Double {
		scoreWeight * scoreNorm(bestScore: bestScore)
			+ recencyWeight * recency(daysSinceLastSung: daysSinceLastSung)
			+ (wantAgain ? wantAgainWeight : 0)
	}

	/// 最高点を 70〜100 点で 0〜1 にする。70 点以下は 0、点数なしは ``missingScoreNorm``。
	static func scoreNorm(bestScore: Double?) -> Double {
		guard let bestScore else { return missingScoreNorm }
		return min(max((bestScore - 70) / 30, 0), 1)
	}

	/// 最後に歌ってからの日数 ÷ ``recencyCapDays``。1 で頭打ち。
	static func recency(daysSinceLastSung: Int) -> Double {
		min(Double(max(daysSinceLastSung, 0)) / Double(recencyCapDays), 1)
	}

	/// `from` から `to` まで何日たったか。日の区切りは ``dayBoundaryHour`` 時。
	static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar) -> Int {
		calendar.dateComponents([.day], from: dayStart(of: from, calendar: calendar), to: dayStart(of: to, calendar: calendar)).day ?? 0
	}

	private static func candidates(from stats: [TrackSingingStats], now: Date, calendar: Calendar) -> [TrackRecommendation] {
		stats.compactMap { stat in
			let days = daysBetween(stat.lastPerformedAt, now, calendar: calendar)
			// 今日歌った曲（未来の日時に直された記録も含む）は出さない
			guard days >= 1 else { return nil }
			// 最新の記録で歌い切れなかった曲は、ハートが付いていても出さない（#128）
			guard stat.latestIsCompleted else { return nil }
			return TrackRecommendation(
				stats: stat,
				score: score(bestScore: stat.bestScore, daysSinceLastSung: days, wantAgain: stat.latestWantAgain),
				daysSinceLastSung: days
			)
		}
	}

	/// スコアの高い順。同じなら最後に歌った日が古い順、それも同じなら曲の ID 順。
	private static func isRankedHigher(_ a: TrackRecommendation, _ b: TrackRecommendation) -> Bool {
		if a.score != b.score { return a.score > b.score }
		if a.stats.lastPerformedAt != b.stats.lastPerformedAt {
			return a.stats.lastPerformedAt < b.stats.lastPerformedAt
		}
		return a.stats.trackId.uuidString < b.stats.trackId.uuidString
	}

	private static func dayStart(of date: Date, calendar: Calendar) -> Date {
		let shifted = calendar.date(byAdding: .hour, value: -dayBoundaryHour, to: date) ?? date
		return calendar.startOfDay(for: shifted)
	}
}
