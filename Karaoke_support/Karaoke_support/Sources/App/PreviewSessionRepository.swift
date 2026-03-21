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
		Self.sampleSessions.filter { $0.intent == intent }
	}

	func exists(uuid: UUID) async throws -> Bool {
		recordedSessionIdsForPreview.contains(uuid)
	}

	private static let sampleSessions: [SingingSession] = {
		let trackA = Track(userEnteredName: "残酷な天使のテーゼ")
		let trackB = Track(spotifyTrackId: "spotify:track:preview")

		return [
			SingingSession(track: trackA, intent: .shout, performedAt: .now.addingTimeInterval(-3600), score: 88),
			SingingSession(track: trackA, intent: .emo, performedAt: .now.addingTimeInterval(-7200), score: 92),
			SingingSession(track: trackB, intent: .practice, performedAt: .now.addingTimeInterval(-10800), score: 75),
		]
	}()
}

