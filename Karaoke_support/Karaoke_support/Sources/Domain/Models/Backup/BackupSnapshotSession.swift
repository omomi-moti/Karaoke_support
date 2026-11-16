#if DEBUG || BETA
import Foundation

/// バックアップに入れる記録。メモは持たない。
/// 保存する値（`recorded…`）は空のまま持ち、読むときの解釈（ADR 0034）はアプリに任せる。
struct BackupSnapshotSession: Codable, Equatable, Sendable {
	let id: UUID
	let trackId: UUID
	let intent: Intent
	let performedAt: Date
	let score: Double?
	let recordedSource: RecordSource?
	let recordedWantAgain: Bool?
	let recordedIsCompleted: Bool?
}
#endif
