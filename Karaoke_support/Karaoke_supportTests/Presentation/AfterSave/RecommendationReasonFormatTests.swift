import Foundation
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

	@Test("「〜前」は「〜ぶり」と同じ数え方")
	func ago() {
		#expect(RecommendationReasonFormat.ago(days: 3) == "3日前")
		#expect(RecommendationReasonFormat.ago(days: 7) == "1週間前")
		#expect(RecommendationReasonFormat.ago(days: 45) == "1ヶ月前")
	}

	private func challenge(intent: Intent, isCompleted: Bool, sessionCount: Int, days: Int) -> TrackRecommendation {
		TrackRecommendation(
			stats: TrackSingingStats(
				trackId: UUID(),
				spotifyTrackId: nil,
				userEnteredName: "曲",
				latestIntent: intent,
				lastPerformedAt: .now,
				bestScore: nil,
				sessionCount: sessionCount,
				latestIsCompleted: isCompleted
			),
			score: 0,
			daysSinceLastSung: days
		)
	}

	@Test("挑戦中で歌い切れなかった曲は「歌い切れず ・ 何日前 ・ 気分」")
	func challengeUnfinished() {
		let text = RecommendationReasonFormat.challenge(challenge(intent: .shout, isCompleted: false, sessionCount: 2, days: 30))
		#expect(text == "歌い切れず ・ 1ヶ月前 ・ Shout")
	}

	@Test("Practice で歌い切れなかった曲も「歌い切れず」になる")
	func challengePracticeUnfinished() {
		let text = RecommendationReasonFormat.challenge(challenge(intent: .practice, isCompleted: false, sessionCount: 1, days: 2))
		#expect(text == "歌い切れず ・ 2日前 ・ Practice")
	}

	@Test("Practice で歌い切れた曲は「点数アップ ・ 何回歌った ・ 前回は何日前」")
	func challengeScoreUp() {
		let text = RecommendationReasonFormat.challenge(challenge(intent: .practice, isCompleted: true, sessionCount: 3, days: 7))
		#expect(text == "点数アップ ・ 3回歌った ・ 前回は1週間前")
	}

	@Test("気分を付けると「気分 ・ 何日ぶり」になる")
	func withIntent() {
		#expect(RecommendationReasonFormat.sinceLastSung(days: 14, intent: .shout) == "Shout ・ 2週間ぶり")
	}
}
