import Foundation

/// 歌手名を直した結果、曲名と歌手名の両方が同じになる別の曲。まとめる前の確認に出す。
struct TrackMergeCandidate: Equatable {
	let trackId: UUID
	let artistName: String
	let singCount: Int
}
