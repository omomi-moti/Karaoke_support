import Foundation

/// 選曲フローで次画面へ渡す選択中の曲情報。
struct SelectedTrack: Hashable, Sendable {
	let spotifyTrackId: String?
	let userEnteredName: String?

	init(spotifyTrackId: String?, userEnteredName: String?) {
		self.spotifyTrackId = spotifyTrackId
		self.userEnteredName = userEnteredName
	}
}

