#if DEBUG || BETA
import Foundation

/// サーバーに送るバックアップの中身（docs/backend_design.md の「バックアップの中身」）。
/// メモはこの型にも、中の型にも持たせない。端末の外に出さないため（憲法 II、ADR 0049）。
struct BackupSnapshot: Codable, Equatable, Sendable {
	/// 送る形の版（NFR-7）。項目を変えたら上げる。読むときは 1 からこの版までを読み、前の版にない項目は空にする（ADR 0067）。
	static let schemaVersion = 2

	let tracks: [BackupSnapshotTrack]
	let sessions: [BackupSnapshotSession]
}
#endif
