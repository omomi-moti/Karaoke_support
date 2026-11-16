#if DEBUG || BETA
import Foundation
import SwiftData

/// バックアップの中身を、空の端末の SwiftData に書き込む（ADR 0061）。端末に全部の記録を書き込むのはここだけ。
/// モデルの `init` は範囲の外の値で止まる（`precondition`）ので、モデルを作る前に値を全部確かめる。
/// 確かめてから保存するまで待ちを挟まないので、途中で自動の保存は走らない。
@MainActor
final class SwiftDataBackupSnapshotWriter: BackupSnapshotWriting {
	private let modelContext: ModelContext

	init(modelContext: ModelContext) {
		self.modelContext = modelContext
	}

	func isEmpty() throws -> Bool {
		do {
			return try modelContext.fetchCount(FetchDescriptor<Track>()) == 0
				&& modelContext.fetchCount(FetchDescriptor<SingingSession>()) == 0
		} catch {
			throw BackupRestoreFailure.localStoreFailed
		}
	}

	func write(_ snapshot: BackupSnapshot) throws {
		guard let names = Self.validatedTrackNames(snapshot) else {
			throw BackupRestoreFailure.invalidContents
		}
		guard try isEmpty() else {
			throw BackupRestoreFailure.localNotEmpty
		}

		let sessionCounts = Dictionary(grouping: snapshot.sessions, by: \.trackId).mapValues(\.count)
		var tracks: [UUID: Track] = [:]
		for item in snapshot.tracks {
			guard let name = names[item.id] else { continue }
			let track = Track(
				id: item.id,
				userEnteredName: name,
				singCount: sessionCounts[item.id] ?? 0,
				createdAt: item.createdAt,
				updatedAtOverride: item.updatedAt
			)
			modelContext.insert(track)
			tracks[item.id] = track
		}
		for item in snapshot.sessions {
			guard let track = tracks[item.trackId] else { continue }
			modelContext.insert(SingingSession(
				restoringID: item.id,
				track: track,
				intent: item.intent,
				performedAt: item.performedAt,
				score: item.score,
				recordedSource: item.recordedSource,
				recordedWantAgain: item.recordedWantAgain,
				recordedIsCompleted: item.recordedIsCompleted
			))
		}

		do {
			try modelContext.save()
		} catch {
			modelContext.rollback()
			throw BackupRestoreFailure.localStoreFailed
		}
	}

	/// 値が全部正しければ、曲の id から曲名への対応を返す。1 件でもおかしければ nil。
	/// 曲名が空でない・曲の id と曲名が重ならない・記録の id が重ならない・記録の曲がある・点数が 0〜100 かを見る。
	/// 気分と記録の入口が知っている値かは、中身を読むときに確かめている。
	private static func validatedTrackNames(_ snapshot: BackupSnapshot) -> [UUID: String]? {
		var names: [UUID: String] = [:]
		var seenNames: Set<String> = []
		for track in snapshot.tracks {
			guard let name = track.userEnteredName, !name.isEmpty,
				names[track.id] == nil,
				seenNames.insert(name).inserted
			else { return nil }
			names[track.id] = name
		}

		var sessionIDs: Set<UUID> = []
		for session in snapshot.sessions {
			guard sessionIDs.insert(session.id).inserted,
				names[session.trackId] != nil,
				session.score.map({ (0...100).contains($0) }) ?? true
			else { return nil }
		}
		return names
	}
}
#endif
