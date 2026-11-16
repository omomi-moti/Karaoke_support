#if DEBUG || BETA
import Foundation

/// サーバーに送るバックアップの中身（docs/backend_design.md の「バックアップの中身」）。
/// メモはこの型にも、中の型にも持たせない。端末の外に出さないため（憲法 II、ADR 0049）。
struct BackupSnapshot: Codable, Equatable, Sendable {
	/// この形の版（NFR-7）。項目を変えたら上げる。
	static let schemaVersion = 1

	let tracks: [BackupSnapshotTrack]
	let sessions: [BackupSnapshotSession]
}
#endif
