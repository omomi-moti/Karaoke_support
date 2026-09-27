import Foundation

/// 曲名サジェストの並べ方。DB では部分一致で絞り込み（`searchLocal`）、並べ方はここで決める。
///
/// 方針は `docs/design/track_matching.md` を参照。
enum TrackSuggestionRanker {
	/// DB 側の `localizedStandardContains` と同じく、大文字小文字・濁点などの違いを区別しない。
	/// 全角半角の違いも区別しない（DB 側で一致した曲を、並べ替えで取りこぼさないように広めにとる）。
	static let compareOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]

	/// 良い段から順に確認し、当てはまった時点で決める（1 曲が複数の段に当てはまる場合は一番良い段に入れる）。
	static func tier(of name: String, for query: String) -> TrackMatchTier {
		if name.range(of: query, options: compareOptions.union(.anchored)) != nil {
			return .prefix
		}
		// 1 回目の一致が単語の途中でも、後ろに単語の先頭での一致があればそちらを採る
		// （例:「an」→「Banana Anthem」は Anthem で単語の先頭一致）
		var searchStart = name.startIndex
		while searchStart < name.endIndex,
		      let range = name.range(of: query, options: compareOptions, range: searchStart ..< name.endIndex) {
			if isWordStart(range.lowerBound, in: name) {
				return .wordPrefix
			}
			searchStart = name.index(after: range.lowerBound)
		}
		// DB 側では一致したのにここで見つからない場合も、候補から落とさず最下段に置く
		return .contains
	}

	/// 段 → 歌唱回数の多い順 → `updatedAt` の新しい順 → 曲名 の順で並べる。
	///
	/// 最後の曲名は、条件がすべて同じ曲の並びを毎回同じにするため（`sorted` は同順位の並びを保証しない）。
	/// `updatedAt` は記録の保存だけでなく編集・削除でも更新されるため、「最後に歌った日時」の近似である。
	static func rank(_ tracks: [Track], query: String) -> [Track] {
		tracks
			.map { (track: $0, tier: tier(of: $0.userEnteredName ?? "", for: query)) }
			.sorted { a, b in
				if a.tier != b.tier { return a.tier < b.tier }
				if a.track.singCount != b.track.singCount { return a.track.singCount > b.track.singCount }
				if a.track.updatedAt != b.track.updatedAt { return a.track.updatedAt > b.track.updatedAt }
				return (a.track.userEnteredName ?? "") < (b.track.userEnteredName ?? "")
			}
			.map(\.track)
	}

	/// 直前が空白・記号（括弧やハイフンなど）なら単語の先頭とみなす。
	///
	/// `enumerateSubstrings(.byWords)` は日本語を形態素で区切り、区切り位置が予想しづらいため使わない。
	private static func isWordStart(_ index: String.Index, in name: String) -> Bool {
		guard index > name.startIndex else { return true }
		let previous = name[name.index(before: index)]
		return previous.isWhitespace || previous.isPunctuation || previous.isSymbol
	}
}
