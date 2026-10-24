import Testing

@testable import Karaoke_support

@Suite("RecommendationReasonFormat")
struct RecommendationReasonFormatTests {

	@Test(
		"日・週・月・年の境目",
		arguments: [
			(1, "1日ぶり"),
			(6, "6日ぶり"),
			(7, "1週間ぶり"),
			(13, "1週間ぶり"),
			(14, "2週間ぶり"),
			(29, "4週間ぶり"),
			(30, "1ヶ月ぶり"),
			(59, "1ヶ月ぶり"),
			(60, "2ヶ月ぶり"),
			(364, "12ヶ月ぶり"),
			(365, "1年ぶり"),
			(800, "2年ぶり"),
		]
	)
	func boundaries(days: Int, expected: String) {
		#expect(RecommendationReasonFormat.sinceLastSung(days: days) == expected)
	}

	@Test("0 日以下は 1 日として出す（提案には今日歌った曲は出ないが、念のため）")
	func clampsToOneDay() {
		#expect(RecommendationReasonFormat.sinceLastSung(days: 0) == "1日ぶり")
	}
}
