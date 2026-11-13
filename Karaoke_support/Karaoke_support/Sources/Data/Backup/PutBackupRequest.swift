#if DEBUG || BETA
import Foundation

/// `PUT /v1/backup` の本文。件数は端末で数えて一緒に送り、サーバーは `payload` の中身を読まない（docs/backend_design.md）。
struct PutBackupRequest: Encodable {
	let schemaVersion: Int
	let trackCount: Int
	let sessionCount: Int
	let payload: BackupSnapshot

	init(snapshot: BackupSnapshot) {
		schemaVersion = BackupSnapshot.schemaVersion
		trackCount = snapshot.tracks.count
		sessionCount = snapshot.sessions.count
		payload = snapshot
	}
}
#endif
