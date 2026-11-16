#if DEBUG || BETA
import Foundation

/// `PUT /v1/backup` の返事。
struct PutBackupResponse: Decodable {
	let revision: Int
	let updatedAt: Date
}
#endif
