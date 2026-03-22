import Foundation

/// プレビュー用の ``SessionRepositoryProtocol`` 実装。
///
/// - `saveNewRecordingSession` で保存した ID を `exists` と整合させる（I-011）。
/// - `updateRecordingSession` は ID が存在すれば成功するが、**`fetchAll` は静的サンプル配列のみ**のため、**更新したフィールドは一覧に反映されない**（本番 SwiftData とは別。編集プレビューが必要なら簡易ストア等の拡張が要る）。
@MainActor
final class PreviewSessionRepository: SessionRepositoryProtocol {
	private var recordedSessionIdsForPreview: Set<UUID> = []

	func saveNewRecordingSession(_ session: SingingSession) async throws {
		if try await exists(uuid: session.id) {
			return
		}
		recordedSessionIdsForPreview.insert(session.id)
	}

	/// 存在チェックのみ本番に近い。更新内容は `fetchAll` にマージしていないため **UI には反映されない**。
	func updateRecordingSession(_ session: SingingSession) async throws {
		guard try await exists(uuid: session.id) else {
			throw SessionRepositoryError.sessionNotFound(session.id)
		}
	}

	func deleteRecordingSession(uuid: UUID) async throws {
		guard recordedSessionIdsForPreview.remove(uuid) != nil else {
			throw SessionRepositoryError.sessionNotFound(uuid)
		}
	}

	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession] {
		let sessions = Self.sampleSessions
		let start = min(offset, sessions.count)
		let end = min(offset + max(limit, 0), sessions.count)
		return Array(sessions[start..<end])
	}

	func fetchByIntent(_ intent: Intent) async throws -> [SingingSession] {
		let rows = try await fetchAll(limit: SessionRecentWindow.maxSessionCount, offset: 0)
		return rows.filter { $0.intent == intent }
	}

	func exists(uuid: UUID) async throws -> Bool {
		recordedSessionIdsForPreview.contains(uuid)
	}

	private static let sampleSessions: [SingingSession] = {
		let t1 = Track(userEnteredName: "アイドル")
		let t2 = Track(userEnteredName: "怪獣の花唄")
		let t3 = Track(userEnteredName: "Subtitle")

		return [
			SingingSession(track: t1, intent: .shout, performedAt: .now.addingTimeInterval(-3600), score: 92.5),
			SingingSession(track: t2, intent: .practice, performedAt: .now.addingTimeInterval(-7200), score: 88.0),
			SingingSession(track: t3, intent: .emo, performedAt: .now.addingTimeInterval(-10800), score: 94.2),
		]
	}()
}

