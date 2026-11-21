#if DEBUG || BETA
import Foundation
import SwiftData

/// SwiftData の全部の曲と記録を、バックアップの中身に写す。メモは読まない。
/// 同じ記録なら同じ中身になるように、id の順に並べる（前回と同じ中身なら送らないため、ADR 0058）。
@MainActor
final class SwiftDataBackupSnapshotReader: BackupSnapshotReading {
	private let modelContext: ModelContext

	init(modelContext: ModelContext) {
		self.modelContext = modelContext
	}

	func readSnapshot() throws -> BackupSnapshot {
		let tracks = try modelContext.fetch(FetchDescriptor<Track>())
		let sessions = try modelContext.fetch(FetchDescriptor<SingingSession>())
		return BackupSnapshot(
			tracks: tracks
				.map {
					BackupSnapshotTrack(
						id: $0.id,
						userEnteredName: $0.userEnteredName,
						userEnteredArtistName: $0.userEnteredArtistName,
						createdAt: $0.createdAt,
						updatedAt: $0.updatedAt
					)
				}
				.sorted { $0.id.uuidString < $1.id.uuidString },
			sessions: sessions
				.map {
					BackupSnapshotSession(
						id: $0.id,
						trackId: $0.track.id,
						intent: $0.intent,
						performedAt: $0.performedAt,
						score: $0.score,
						recordedSource: $0.recordedSource,
						recordedWantAgain: $0.recordedWantAgain,
						recordedIsCompleted: $0.recordedIsCompleted
					)
				}
				.sorted { $0.id.uuidString < $1.id.uuidString }
		)
	}
}
#endif
