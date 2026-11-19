import Foundation

/// 曲名が同じで歌手名のない前からの曲を、今の記録と同じ曲とするか（ADR 0011）。
///
/// どの曲についての答えかを `trackId` で持つ。曲名を変えて別の曲が見つかったら、前の答えは使わない。
enum ArtistlessTrackChoice: Sendable, Equatable {
	/// 同じ曲。保存するときに、その曲に歌手名を書き足す
	case sameTrack(trackId: UUID)
	/// 別の曲。前の曲はそのままにして、新しい曲を作る
	case differentTrack(trackId: UUID)

	var trackId: UUID {
		switch self {
		case .sameTrack(let trackId), .differentTrack(let trackId):
			return trackId
		}
	}
}
