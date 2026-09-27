import Foundation

/// 記録シートの曲名サジェスト（もしかして）1 件分。`Track` を View に渡さず値型に写す。
struct TrackSuggestion: Identifiable, Hashable, Sendable {
	let trackId: UUID
	/// 押したときに入力欄へ入れる曲名（保存済みの ``Track/userEnteredName`` そのもの）。
	let name: String
	let singCount: Int

	var id: UUID { trackId }

	/// 手入力の曲として保存できない Track は `nil`。
	///
	/// 候補を押すと曲名だけが入力欄に入り、保存時は `getOrCreate(spotifyTrackId: nil, userEnteredName:)` で照合される。
	/// この照合は Spotify ID を持たない Track しか探さないため、Spotify ID を持つ Track を候補にすると別の Track が作られる。
	init?(track: Track) {
		guard track.spotifyTrackId == nil, let name = track.userEnteredName, !name.isEmpty else { return nil }
		self.trackId = track.id
		self.name = name
		self.singCount = track.singCount
	}
}
