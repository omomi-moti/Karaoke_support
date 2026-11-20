import Foundation

/// ``TrackRepositoryProtocol/updateArtistName(_:trackId:)`` の結果。
enum ArtistNameUpdateResult {
	/// 歌手名を直した。
	case updated(Track)
	/// 曲名と歌手名の両方が同じ別の曲があるので、書かなかった。
	case conflicts(with: Track)
}
