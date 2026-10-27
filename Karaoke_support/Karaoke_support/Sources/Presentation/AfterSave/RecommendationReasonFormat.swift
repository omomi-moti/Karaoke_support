import Foundation

/// 提案カードの理由の行（#115）。例:「2ヶ月ぶり」。
enum RecommendationReasonFormat {
	/// 6 日までは日、29 日までは週、364 日までは月、それ以上は年で数える（端数は切り捨て）。
	static func sinceLastSung(days: Int) -> String {
		let days = max(days, 1)
		switch days {
		case ..<7: return "\(days)日ぶり"
		case ..<30: return "\(days / 7)週間ぶり"
		case ..<365: return "\(days / 30)ヶ月ぶり"
		default: return "\(days / 365)年ぶり"
		}
	}

	/// 選曲画面で、今の気分と違う曲に気分を付ける（#126）。例:「Shout ・ 2週間ぶり」。
	static func sinceLastSung(days: Int, intent: Intent) -> String {
		"\(IntentLabel.title(intent)) ・ \(sinceLastSung(days: days))"
	}
}
