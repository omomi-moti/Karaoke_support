#if DEBUG || BETA
import Foundation

/// 端末の全部の記録を、バックアップの中身にして返すもの。テストでは偽物に差し替える。
@MainActor
protocol BackupSnapshotReading: Sendable {
	func readSnapshot() throws -> BackupSnapshot
}
#endif
