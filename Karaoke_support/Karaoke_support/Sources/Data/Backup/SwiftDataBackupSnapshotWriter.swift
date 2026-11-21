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
			guard let entry = names[item.id] else { continue }
			let track = Track(
				id: item.id,
				userEnteredName: entry.name,
				userEnteredArtistName: entry.artist,
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

	/// 値が全部正しければ、曲の id から曲名と歌手名への対応を返す。1 件でもおかしければ nil。
	/// 曲名が空でない・曲の id が重ならない・曲名と歌手名の組が重ならない（歌手名が空どうしも同じとみなす、ADR 0067）・
	/// 記録の id が重ならない・記録の曲がある・点数が 0〜100 かを見る。空文字の歌手名は、端末で保存するときと同じく空として扱う。
	/// 気分と記録の入口が知っている値かは、中身を読むときに確かめている。
	private static func validatedTrackNames(_ snapshot: BackupSnapshot) -> [UUID: (name: String, artist: String?)]? {
		var names: [UUID: (name: String, artist: String?)] = [:]
		var seenKeys: Set<[String?]> = []
		for track in snapshot.tracks {
			let artist = track.userEnteredArtistName.flatMap { $0.isEmpty ? nil : $0 }
			guard let name = track.userEnteredName, !name.isEmpty,
				names[track.id] == nil,
				seenKeys.insert([name, artist]).inserted
			else { return nil }
			names[track.id] = (name, artist)
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
