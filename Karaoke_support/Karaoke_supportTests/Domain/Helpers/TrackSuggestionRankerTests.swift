import Foundation
import Testing

@testable import Karaoke_support

@Suite("TrackSuggestionRanker")
@MainActor
struct TrackSuggestionRankerTests {

	private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

	private func makeTrack(_ name: String, singCount: Int = 1, updatedAt: Date? = nil) -> Track {
		Track(
			userEnteredName: name,
			singCount: singCount,
			createdAt: baseDate,
			updatedAtOverride: updatedAt ?? baseDate
		)
	}

	private func rankedNames(_ tracks: [Track], query: String) -> [String] {
		TrackSuggestionRanker.rank(tracks, query: query).map { $0.userEnteredName ?? "" }
	}

	// MARK: 段の判定

	/// 段の判定を決めたケースの一覧。ルールを変えたときに、どのケースの結果が変わったかがここで分かるようにする。
	/// アポストロフィの扱いは、文字の場合は Unicode の単語の区切り規則と同じ。数字の場合（90's）は独自の判断（docs/design/track_matching.md）。
	@Test(
		"段の判定",
		arguments: [
			// 前方一致（大文字小文字・全角半角は区別しない）
			("lemon", "le", TrackMatchTier.prefix),
			("LEMON", "le", .prefix),
			("ＬＥＭＯＮ", "le", .prefix),
			("打上花火", "打上", .prefix),
			// 直前が空白・記号なら単語の先頭一致
			("Lemon (Live)", "live", .wordPrefix),
			("Hello Again", "ag", .wordPrefix),
			("Banana Anthem", "an", .wordPrefix),  // 1 回目の一致は単語の途中、後ろの Anthem で単語の先頭
			// アポストロフィが文字・数字にはさまれていれば単語の途中
			("Don't Stop", "t", .contains),
			("Don’t Stop", "t", .contains),  // 右シングル引用符（’）
			("Rock'n'Roll", "n", .contains),
			("90's Love", "s", .contains),
			("L'amour", "amour", .contains),  // 文字だけでは英語の短縮形と見分けられないため、単語の途中として扱う仕様
			("O'Brien", "brien", .contains),
			// 先頭や空白の後ろのアポストロフィ（省略）の後ろは単語の先頭一致
			("'Round Midnight", "round", .wordPrefix),
			("Take ’Em All", "em", .wordPrefix),
			("Rock'n' Roll", "roll", .wordPrefix),
			// どれでもなければ部分一致
			("lemon", "mon", .contains),
			("打上花火", "花火", .contains),  // 空白のない日本語は途中で一致すれば部分一致
		]
	)
	func tierCases(name: String, query: String, expected: TrackMatchTier) {
		#expect(TrackSuggestionRanker.tier(of: name, for: query) == expected)
	}

	// MARK: 並べ替え

	@Test("段は歌唱回数より優先される")
	func tierBeatsSingCount() {
		let tracks = [
			makeTrack("Banana", singCount: 20),
			makeTrack("Ado", singCount: 1),
		]

		#expect(rankedNames(tracks, query: "a") == ["Ado", "Banana"])
	}

	@Test("1 文字でも 前方一致 → 単語の先頭一致 → 部分一致 の順になる")
	func oneCharacterQueryUsesAllTiers() {
		let tracks = [
			makeTrack("Banana", singCount: 30),       // 部分一致
			makeTrack("Hello Again", singCount: 20),  // 単語の先頭一致
			makeTrack("Ado", singCount: 1),           // 前方一致
		]

		#expect(rankedNames(tracks, query: "a") == ["Ado", "Hello Again", "Banana"])
	}

	@Test("アポストロフィの直後で一致した曲が、回数の多い部分一致の曲より上に来ない")
	func apostropheMatchDoesNotOutrankMoreSungContains() {
		// シミュレータで再現した並び: n → nnnn / Rock'n'Roll(1回) / lemon(4回)
		let tracks = [
			makeTrack("Rock'n'Roll", singCount: 1),
			makeTrack("lemon", singCount: 4),
			makeTrack("nnnn", singCount: 1),
		]

		#expect(rankedNames(tracks, query: "n") == ["nnnn", "lemon", "Rock'n'Roll"])
	}

	@Test("同じ段の中では歌唱回数の多い順")
	func sameTierSortsBySingCount() {
		let tracks = [
			makeTrack("lemon", singCount: 3),
			makeTrack("lemonade", singCount: 10),
		]

		#expect(rankedNames(tracks, query: "le") == ["lemonade", "lemon"])
	}

	@Test("段も回数も同じなら updatedAt の新しい順")
	func sameSingCountSortsByUpdatedAt() {
		let tracks = [
			makeTrack("lemon", singCount: 3, updatedAt: baseDate),
			makeTrack("lemonade", singCount: 3, updatedAt: baseDate.addingTimeInterval(60)),
		]

		#expect(rankedNames(tracks, query: "le") == ["lemonade", "lemon"])
	}

	@Test("すべて同じなら曲名の順で、入力の並びに関係なく毎回同じ並びになる")
	func fullTieSortsByNameDeterministically() {
		let a = makeTrack("lemon a", singCount: 3)
		let b = makeTrack("lemon b", singCount: 3)

		#expect(rankedNames([a, b], query: "le") == ["lemon a", "lemon b"])
		#expect(rankedNames([b, a], query: "le") == ["lemon a", "lemon b"])
	}
}
