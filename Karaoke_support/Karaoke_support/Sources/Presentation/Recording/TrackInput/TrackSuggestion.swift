import Foundation

/// 記録シートの曲名サジェスト（もしかして）1 件分。`Track` を View に渡さず値型に写す。
struct TrackSuggestion: Identifiable, Hashable, Sendable {
	let trackId: UUID
	/// 押したときに入力欄へ入れる曲名（保存済みの ``Track/userEnteredName`` そのもの）。
	let name: String
	let singCount: Int

	var id: UUID { trackId }

	/// 手入力の曲名を持たない Track（Spotify 由来）は入力欄に入れられないので `nil`。
	init?(track: Track) {
		guard let name = track.userEnteredName, !name.isEmpty else { return nil }
		self.trackId = track.id
		self.name = name
		self.singCount = track.singCount
	}
}
