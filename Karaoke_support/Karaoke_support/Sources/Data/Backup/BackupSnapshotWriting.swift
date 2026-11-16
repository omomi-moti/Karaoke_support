#if DEBUG || BETA
import Foundation

/// バックアップの中身を、空の端末に書き込むもの（ADR 0061）。テストでは偽物に差し替える。
@MainActor
protocol BackupSnapshotWriting: Sendable {
	/// 端末に曲も記録も 1 件もないか。
	func isEmpty() throws -> Bool

	/// 空の端末に `snapshot` を全部書き込み、1 回だけ保存する。
	/// 値がおかしければ ``BackupRestoreFailure/invalidContents``、空でなければ ``BackupRestoreFailure/localNotEmpty``、
	/// 読み書きに失敗したら ``BackupRestoreFailure/localStoreFailed`` を投げ、どの場合も何も残さない。
	func write(_ snapshot: BackupSnapshot) throws
}
#endif
