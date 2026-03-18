import Foundation

/// 記録シートでの曲入力方法。
enum TrackInputMode: Sendable, Equatable {
	/// 手動入力（編集可）
	case manual
	/// Spotify履歴から（表示は固定、IDはspotifyTrackId）
	case spotifyHistory(spotifyTrackId: String, displayName: String)
	/// SwiftData履歴から（表示は固定）
	case localTrack(trackId: UUID, spotifyTrackId: String?, userEnteredName: String?)
}

