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

	@Test("先頭から一致すれば前方一致")
	func prefixMatch() {
		#expect(TrackSuggestionRanker.tier(of: "lemon", for: "le") == .prefix)
	}

	@Test("大文字小文字・全角半角が違っても前方一致", arguments: ["LEMON", "ＬＥＭＯＮ", "Lemon"])
	func prefixMatchIgnoresCaseAndWidth(name: String) {
		#expect(TrackSuggestionRanker.tier(of: name, for: "le") == .prefix)
	}

	@Test("直前が記号の位置で一致すれば単語の先頭一致")
	func wordPrefixAfterSymbol() {
		#expect(TrackSuggestionRanker.tier(of: "Lemon (Live)", for: "live") == .wordPrefix)
	}

	@Test("直前が空白の位置で一致すれば単語の先頭一致")
	func wordPrefixAfterSpace() {
		#expect(TrackSuggestionRanker.tier(of: "Hello Again", for: "ag") == .wordPrefix)
	}

	@Test("1 回目の一致が単語の途中でも、後ろに単語の先頭での一致があれば単語の先頭一致")
	func laterWordStartOccurrenceWins() {
		#expect(TrackSuggestionRanker.tier(of: "Banana Anthem", for: "an") == .wordPrefix)
	}

	@Test(
		"アポストロフィは単語の途中に入る文字なので、その直後は単語の先頭とみなさない",
		arguments: [
			("Rock'n'Roll", "n"),
			("Don't Stop", "t"),
			("Don’t Stop", "t"),  // 右シングル引用符（’）
		]
	)
	func apostropheIsNotWordBoundary(name: String, query: String) {
		#expect(TrackSuggestionRanker.tier(of: name, for: query) == .contains)
	}

	@Test("アポストロフィの後ろに空白があれば、その先は単語の先頭一致のまま")
	func wordAfterApostropheAndSpaceIsWordPrefix() {
		#expect(TrackSuggestionRanker.tier(of: "Rock'n' Roll", for: "roll") == .wordPrefix)
	}

	@Test("単語の途中でしか一致しなければ部分一致")
	func containsMatch() {
		#expect(TrackSuggestionRanker.tier(of: "lemon", for: "mon") == .contains)
	}

	@Test("空白のない日本語の途中で一致すれば部分一致")
	func japaneseWithoutSpacesIsContains() {
		#expect(TrackSuggestionRanker.tier(of: "打上花火", for: "花火") == .contains)
	}

	@Test("日本語でも先頭から一致すれば前方一致")
	func japanesePrefix() {
		#expect(TrackSuggestionRanker.tier(of: "打上花火", for: "打上") == .prefix)
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
