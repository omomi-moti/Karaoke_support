#if DEBUG || BETA
import Foundation

@MainActor
final class PreviewBackupRepository: BackupRepositoryProtocol {
	private(set) var status: BackupStatus
	private var restorable: BackupRestorableSummary?

	/// ほかのプレビュー用の Repository とそろえる（ADR 0027）。環境の初期値は nil なので、これは使わない（ADR 0055）。
	nonisolated init(
		status: BackupStatus = BackupStatus(isEnabled: false, consentVersion: nil, lastSucceededAt: nil, lastFailure: nil),
		restorable: BackupRestorableSummary? = nil
	) {
		self.status = status
		self.restorable = restorable
	}

	func enable() async throws -> BackupOutcome {
		status = BackupStatus(isEnabled: true, consentVersion: BackupStatus.currentConsentVersion, lastSucceededAt: Date(), lastFailure: nil)
		return .uploaded
	}

	func backUp(trigger: BackupTrigger) async throws -> BackupOutcome {
		guard status.isActive else { return .notActive }
		status = BackupStatus(isEnabled: true, consentVersion: status.consentVersion, lastSucceededAt: Date(), lastFailure: nil)
		return .uploaded
	}

	func fetchConflict() async throws -> BackupConflict {
		BackupConflict(serverRevision: 3, serverSessionCount: 42, localSessionCount: 38)
	}

	func replaceRemote(confirmed conflict: BackupConflict) async throws -> BackupOutcome {
		status = BackupStatus(isEnabled: true, consentVersion: status.consentVersion, lastSucceededAt: Date(), lastFailure: nil)
		return .uploaded
	}

	func fetchRemoteSessionCount() async throws -> Int? {
		42
	}

	func disable() async throws {
		status = BackupStatus(isEnabled: false, consentVersion: nil, lastSucceededAt: nil, lastFailure: nil)
	}

	func retryRemoteDeletion() async throws {
		try await disable()
	}

	func fetchRestorableBackup() async throws -> BackupRestorableSummary? {
		restorable
	}

	func restoreAll() async throws -> Int {
		let count = restorable?.sessionCount ?? 0
		restorable = nil
		return count
	}
}
#endif
