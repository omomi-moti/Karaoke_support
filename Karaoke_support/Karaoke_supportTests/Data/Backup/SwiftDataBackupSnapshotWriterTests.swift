#if DEBUG || BETA
import Foundation
import SwiftData
import Testing

@testable import Karaoke_support

private let trackA = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
private let trackB = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
private let baseDate = Date(timeIntervalSince1970: 1_700_000_000.25)

private func track(_ id: UUID = trackA, name: String? = "曲A", artist: String? = nil) -> BackupSnapshotTrack {
	BackupSnapshotTrack(id: id, userEnteredName: name, userEnteredArtistName: artist, createdAt: baseDate, updatedAt: baseDate.addingTimeInterval(60))
}

private func session(_ index: Int, trackId: UUID = trackA, score: Double? = 80) -> BackupSnapshotSession {
	BackupSnapshotSession(
		id: UUID(uuidString: String(format: "00000000-0000-0000-0001-%012d", index))!,
		trackId: trackId, intent: .emo, performedAt: baseDate.addingTimeInterval(Double(index)), score: score,
		recordedSource: .suggestion, recordedWantAgain: true, recordedIsCompleted: false
	)
}

@Suite("SwiftDataBackupSnapshotWriter")
@MainActor
struct SwiftDataBackupSnapshotWriterTests {
	private let container: ModelContainer
	private var context: ModelContext { container.mainContext }

	init() throws {
		container = try ModelContainer(for: Track.self, SingingSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
	}

	/// 曲と記録の件数。
	private func counts() throws -> [Int] {
		[try context.fetchCount(FetchDescriptor<Track>()), try context.fetchCount(FetchDescriptor<SingingSession>())]
	}

	@Test("空の端末に書き込むと、読む処理で読み直したときに同じ中身になる")
	func roundTrip() throws {
		let snapshot = BackupSnapshot(
			tracks: [track(), track(trackB, name: "曲B")],
			sessions: [session(1), session(2), session(3, trackId: trackB, score: nil)]
		)

		try SwiftDataBackupSnapshotWriter(modelContext: context).write(snapshot)

		#expect(try SwiftDataBackupSnapshotReader(modelContext: context).readSnapshot() == snapshot)
	}

	@Test("歌った回数は記録の件数から数え、記録のない曲は 0 にする。メモは空")
	func singCountAndMemo() throws {
		let lonely = UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!
		let snapshot = BackupSnapshot(
			tracks: [track(), track(trackB, name: "曲B"), track(lonely, name: "曲C")],
			sessions: [session(1), session(2), session(3, trackId: trackB)]
		)

		try SwiftDataBackupSnapshotWriter(modelContext: context).write(snapshot)

		let tracks = try context.fetch(FetchDescriptor<Track>())
		let singCounts = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0.singCount) })
		#expect(singCounts == [trackA: 2, trackB: 1, lonely: 0])
		#expect(try context.fetch(FetchDescriptor<SingingSession>()).allSatisfy { $0.memo == nil })
	}

	@Test("保存する値（recorded…）が空の記録は、空のまま戻す")
	func keepsEmptyRecordedValues() throws {
		let old = BackupSnapshotSession(
			id: UUID(), trackId: trackA, intent: .shout, performedAt: baseDate, score: nil,
			recordedSource: nil, recordedWantAgain: nil, recordedIsCompleted: nil
		)

		try SwiftDataBackupSnapshotWriter(modelContext: context).write(BackupSnapshot(tracks: [track()], sessions: [old]))

		let restored = try #require(try context.fetch(FetchDescriptor<SingingSession>()).first)
		#expect(restored.recordedSource == nil)
		#expect(restored.recordedWantAgain == nil)
		#expect(restored.recordedIsCompleted == nil)
		#expect(restored.source == .manual)
	}

	@Test("値が 1 件でもおかしければ、何も書かない", arguments: [
		("曲名が空", BackupSnapshot(tracks: [track(name: "")], sessions: [])),
		("曲名がない", BackupSnapshot(tracks: [track(name: nil)], sessions: [])),
		("曲の id が重なる", BackupSnapshot(tracks: [track(), track(name: "曲B")], sessions: [])),
		("曲名が重なる", BackupSnapshot(tracks: [track(), track(trackB)], sessions: [])),
		("記録の id が重なる", BackupSnapshot(tracks: [track()], sessions: [session(1), session(1)])),
		("記録の曲がない", BackupSnapshot(tracks: [track()], sessions: [session(1), session(2, trackId: trackB)])),
		("点数が 100 を超える", BackupSnapshot(tracks: [track()], sessions: [session(1), session(2, score: 100.001)])),
		("点数が負", BackupSnapshot(tracks: [track()], sessions: [session(1, score: -1)])),
	])
	func rejectsInvalidContents(_ reason: String, snapshot: BackupSnapshot) throws {
		#expect(throws: BackupRestoreFailure.invalidContents, "\(reason)") {
			try SwiftDataBackupSnapshotWriter(modelContext: context).write(snapshot)
		}
		#expect(try counts() == [0, 0])
	}

	@Test("端末に記録があれば、何も書かない")
	func refusesDeviceWithRecords() throws {
		let localTrack = Track(userEnteredName: "端末の曲")
		context.insert(localTrack)
		context.insert(SingingSession(track: localTrack, intent: .practice, score: nil))
		try context.save()

		#expect(throws: BackupRestoreFailure.localNotEmpty) {
			try SwiftDataBackupSnapshotWriter(modelContext: context).write(BackupSnapshot(tracks: [track()], sessions: [session(1)]))
		}
		#expect(try counts() == [1, 1])
	}

	@Test("曲だけが残っている端末も、空としない")
	func refusesDeviceWithTracksOnly() throws {
		context.insert(Track(userEnteredName: "記録を消した曲"))
		try context.save()
		let writer = SwiftDataBackupSnapshotWriter(modelContext: context)

		#expect(try !writer.isEmpty())
		#expect(throws: BackupRestoreFailure.localNotEmpty) {
			try writer.write(BackupSnapshot(tracks: [track()], sessions: []))
		}
		#expect(try counts() == [1, 0])
	}

	@Test("何もない端末は空とする")
	func emptyDevice() throws {
		#expect(try SwiftDataBackupSnapshotWriter(modelContext: context).isEmpty())
	}
}
#endif
