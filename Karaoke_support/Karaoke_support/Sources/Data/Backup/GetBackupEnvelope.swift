#if DEBUG || BETA
import Foundation

/// `GET /v1/backup` の返事のうち、中身より先に読むところ。`schemaVersion` を確かめてから中身（``GetBackupPayload``）を読む。
/// 知らない形の中身を、今の形として読もうとして失敗しないため（NFR-7）。
struct GetBackupEnvelope: Decodable {
	let revision: Int
	let schemaVersion: Int
}
#endif
