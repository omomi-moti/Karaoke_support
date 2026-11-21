#if DEBUG || BETA
import Foundation
import SwiftData
import Testing

@testable import Karaoke_support

@Suite("SwiftDataBackupSnapshotReader")
@MainActor
struct SwiftDataBackupSnapshotReaderTests {
	@Test("記録がなければ、空の中身を返す")
	func emptyStore() throws {
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
		let snapshot = try SwiftDataBackupSnapshotReader(modelContext: container.mainContext).readSnapshot()
		#expect(snapshot == BackupSnapshot(tracks: [], sessions: []))
	}

	@Test("曲と記録の値を写し、保存する値（recorded…）は空のまま写す")
	func mapsValues() throws {
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
		let context = container.mainContext
		let created = Date(timeIntervalSince1970: 1_700_000_000)
		let track = Track(userEnteredName: "曲A", userEnteredArtistName: "歌手A", createdAt: created, updatedAtOverride: created.addingTimeInterval(60))
		let session = SingingSession(
			track: track, intent: .emo, performedAt: created.addingTimeInterval(120), score: 91.234,
			memo: "メモ", source: .suggestion, wantAgain: true, isCompleted: false
		)
		context.insert(track)
		context.insert(session)
		let old = SingingSession(track: track, intent: .shout, score: nil)
		old.recordedWantAgain = nil
		old.recordedIsCompleted = nil
		context.insert(old)
		try context.save()

		let snapshot = try SwiftDataBackupSnapshotReader(modelContext: context).readSnapshot()

		#expect(snapshot.tracks == [
			BackupSnapshotTrack(id: track.id, userEnteredName: "曲A", userEnteredArtistName: "歌手A", createdAt: created, updatedAt: created.addingTimeInterval(60)),
		])
		let mapped = try #require(snapshot.sessions.first { $0.id == session.id })
		#expect(mapped == BackupSnapshotSession(
			id: session.id, trackId: track.id, intent: .emo, performedAt: created.addingTimeInterval(120), score: 91.234,
			recordedSource: .suggestion, recordedWantAgain: true, recordedIsCompleted: false
		))
		let mappedOld = try #require(snapshot.sessions.first { $0.id == old.id })
		#expect(mappedOld.score == nil)
		#expect(mappedOld.recordedWantAgain == nil)
		#expect(mappedOld.recordedIsCompleted == nil)
	}

	@Test("同じ記録なら、何度読んでも同じ並びになる")
	func stableOrder() throws {
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
		let context = container.mainContext
		for index in 0..<5 {
			let track = Track(userEnteredName: "曲\(index)")
			context.insert(track)
			context.insert(SingingSession(track: track, intent: .practice, score: nil))
		}
		try context.save()
		let reader = SwiftDataBackupSnapshotReader(modelContext: context)

		let first = try reader.readSnapshot()
		let second = try reader.readSnapshot()

		#expect(first == second)
		#expect(first.sessions.map(\.id.uuidString) == first.sessions.map(\.id.uuidString).sorted())
		#expect(first.tracks.map(\.id.uuidString) == first.tracks.map(\.id.uuidString).sorted())
	}
}
#endif
