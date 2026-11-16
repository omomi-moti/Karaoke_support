#if DEBUG || BETA
import Foundation

/// `GET /v1/backup` の返事の中身。``GetBackupEnvelope`` で `schemaVersion` を確かめてから読む。
struct GetBackupPayload: Decodable {
	let payload: BackupSnapshot
}
#endif
