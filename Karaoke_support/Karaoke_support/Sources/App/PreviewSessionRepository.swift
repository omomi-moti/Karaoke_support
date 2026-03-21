import Foundation

@MainActor
final class PreviewSessionRepository: SessionRepositoryProtocol {
	/// プレビュー用。`saveNewRecordingSession` で「保存した」ID を保持し I-011 の `exists` と整合させる。
	private var recordedSessionIdsForPreview: Set<UUID> = []

	func saveNewRecordingSession(_ session: SingingSession) async throws {
		if try await exists(uuid: session.id) {
			return
		}
		recordedSessionIdsForPreview.insert(session.id)
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

