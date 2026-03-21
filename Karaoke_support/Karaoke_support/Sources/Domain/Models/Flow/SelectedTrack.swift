import Foundation

/// 選曲フローで次画面へ渡す選択中の曲情報。
/// 少なくとも ``spotifyTrackId`` と ``userEnteredName`` のうち片方は非空（前後空白を除く）。
struct SelectedTrack: Hashable, Sendable {
	let spotifyTrackId: String?
	let userEnteredName: String?

	/// - Returns: trim 後に両方とも空なら `nil`。
	init?(spotifyTrackId: String?, userEnteredName: String?) {
		let normalizedSpotify = spotifyTrackId.flatMap { id in
			let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
			return trimmed.isEmpty ? nil : trimmed
		}
		let normalizedUser = userEnteredName.flatMap { name in
			let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
			return trimmed.isEmpty ? nil : trimmed
		}
		guard normalizedSpotify != nil || normalizedUser != nil else {
			return nil
		}
		self.spotifyTrackId = normalizedSpotify
		self.userEnteredName = normalizedUser
	}
}
