#if DEBUG || BETA
import Foundation

/// `GET /v1/backup/summary` の返事。
struct BackupSummaryResponse: Decodable {
	let revision: Int
	let schemaVersion: Int
	let trackCount: Int
	let sessionCount: Int
	let updatedAt: Date
}
#endif
