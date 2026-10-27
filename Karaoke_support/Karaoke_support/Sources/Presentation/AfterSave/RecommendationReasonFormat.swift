import Foundation

/// 提案カードの理由の行（#115）。例:「2ヶ月ぶり」。
enum RecommendationReasonFormat {
	/// 6 日までは日、29 日までは週、364 日までは月、それ以上は年で数える（端数は切り捨て）。
	static func sinceLastSung(days: Int) -> String {
		"\(period(days: days))ぶり"
	}

	/// ``sinceLastSung(days:)`` と同じ数え方で「〜前」にする。例:「1週間前」。
	static func ago(days: Int) -> String {
		"\(period(days: days))前"
	}

	/// 選曲画面で、今の気分と違う曲に気分を付ける（#126）。例:「Shout ・ 2週間ぶり」。
	static func sinceLastSung(days: Int, intent: Intent) -> String {
		"\(IntentLabel.title(intent)) ・ \(sinceLastSung(days: days))"
	}

	/// 挑戦中の曲（#131）。歌い切れなかった曲は「歌い切れず ・ 1ヶ月前 ・ Shout」、
	/// それ以外（最新の気分が Practice）は「点数アップ ・ 3回歌った ・ 前回は1週間前」。
	static func challenge(_ recommendation: TrackRecommendation) -> String {
		let stats = recommendation.stats
		let days = recommendation.daysSinceLastSung
		if !stats.latestIsCompleted {
			return "歌い切れず ・ \(ago(days: days)) ・ \(IntentLabel.title(stats.latestIntent))"
		}
		return "点数アップ ・ \(stats.sessionCount)回歌った ・ 前回は\(ago(days: days))"
	}

	private static func period(days: Int) -> String {
		let days = max(days, 1)
		switch days {
		case ..<7: return "\(days)日"
		case ..<30: return "\(days / 7)週間"
		case ..<365: return "\(days / 30)ヶ月"
		default: return "\(days / 365)年"
		}
	}
}
