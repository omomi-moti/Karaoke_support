#if DEBUG || BETA
import Foundation

/// バックアップに入れる曲。`singCount` は取り込むときに記録の件数から数え直すので持たない。`spotifyTrackId` は今は常に空なので持たない。
struct BackupSnapshotTrack: Codable, Equatable, Sendable {
	let id: UUID
	let userEnteredName: String?
	/// 版 2 から。前の版の控えと、歌手名のない前からの曲では空（ADR 0067）。
	let userEnteredArtistName: String?
	let createdAt: Date
	let updatedAt: Date
}
#endif
