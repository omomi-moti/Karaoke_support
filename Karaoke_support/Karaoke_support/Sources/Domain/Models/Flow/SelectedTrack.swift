import Foundation

/// 選曲フローで次画面へ渡す選択中の曲情報。
/// 少なくとも ``spotifyTrackId`` と ``userEnteredName`` のうち片方は非空（前後空白を除く）。
struct SelectedTrack: Hashable, Sendable {
	let spotifyTrackId: String?
	let userEnteredName: String?
	/// 手入力の曲の歌手名。歌手名のない曲は `nil`。
	let userEnteredArtistName: String?

	/// - Returns: trim 後に Spotify ID と曲名の両方とも空なら `nil`。歌手名だけでは曲にならない。
	init?(spotifyTrackId: String?, userEnteredName: String?, userEnteredArtistName: String? = nil) {
		let normalizedSpotify = Self.trimmedNonEmpty(spotifyTrackId)
		let normalizedUser = Self.trimmedNonEmpty(userEnteredName)
		guard normalizedSpotify != nil || normalizedUser != nil else {
			return nil
		}
		self.spotifyTrackId = normalizedSpotify
		self.userEnteredName = normalizedUser
		self.userEnteredArtistName = Self.trimmedNonEmpty(userEnteredArtistName)
	}

	private static func trimmedNonEmpty(_ value: String?) -> String? {
		value.flatMap { raw in
			let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
			return trimmed.isEmpty ? nil : trimmed
		}
	}
}
