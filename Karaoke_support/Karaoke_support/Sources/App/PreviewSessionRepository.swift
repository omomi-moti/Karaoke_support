import Foundation

/// プレビュー用の ``SessionRepositoryProtocol`` 実装。
///
/// - `saveNewRecordingSession` で保存した ID を `exists` と整合させる（I-011）。
/// - `updateRecordingSession` は ID が存在すれば成功するが、**`fetchAll` は静的サンプル配列のみ**のため、**更新したフィールドは一覧に反映されない**（本番 SwiftData とは別。I-014-C: 編集保存後もプレビュー一覧は静的サンプルのまま）。
/// - サンプル行を `deleteRecordingSession` した ID は `deletedSampleSessionIds` で除外し、`exists` / `fetchAll` / `fetchRecordingSession` と契約を揃える。
@MainActor
final class PreviewSessionRepository: SessionRepositoryProtocol {
	private var recordedSessionIdsForPreview: Set<UUID> = []
	/// プレビュー上で削除した固定サンプル行の ID（`sampleSessions` から論理削除）。
	private var deletedSampleSessionIds: Set<UUID> = []

	/// `offset + limit` が `Int` でオーバーフローしてもスライス終端を安全に得る。
	private func sliceEnd(offset: Int, limit: Int, count: Int) -> Int {
		let (sum, overflow) = offset.addingReportingOverflow(limit)
		let raw = overflow ? count : sum
		return min(raw, count)
	}

	/// プレビュー用固定 UUID 文字列から UUID を生成する。
	/// 変換に失敗した場合は `assertionFailure` を発火し、フォールバックとしてランダム UUID を返す。
	private static func makeUUID(_ literal: String) -> UUID {
		guard let uuid = UUID(uuidString: literal) else {
			assertionFailure("Invalid UUID literal for PreviewSessionRepository: \(literal)")
			return UUID()
		}
		return uuid
	}

	/// サンプル行と `fetchRecordingSession` 用（固定リテラル）。
	private static let sampleId1 = makeUUID("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEE0001")
	private static let sampleId2 = makeUUID("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEE0002")
	private static let sampleId3 = makeUUID("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEE0003")

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
		if recordedSessionIdsForPreview.remove(uuid) != nil {
			return
		}
		if Self.sampleSessions.contains(where: { $0.id == uuid }) {
			deletedSampleSessionIds.insert(uuid)
			return
		}
		throw SessionRepositoryError.sessionNotFound(uuid)
	}

	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession] {
		guard limit >= 0, offset >= 0 else {
			throw SessionRepositoryError.invalidParameter("limit and offset must be non-negative")
		}
		let sessions = Self.sampleSessions.filter { !deletedSampleSessionIds.contains($0.id) }
		let start = min(offset, sessions.count)
		let end = sliceEnd(offset: offset, limit: limit, count: sessions.count)
		return Array(sessions[start..<end])
	}

	func fetchByIntent(_ intent: Intent, limit: Int, offset: Int) async throws -> [SingingSession] {
		guard limit >= 0, offset >= 0 else {
			throw SessionRepositoryError.invalidParameter("limit and offset must be non-negative")
		}
		let sessions = Self.sampleSessions
			.filter { !deletedSampleSessionIds.contains($0.id) && $0.intent == intent }
		let start = min(offset, sessions.count)
		let end = sliceEnd(offset: offset, limit: limit, count: sessions.count)
		return Array(sessions[start..<end])
	}

	func exists(uuid: UUID) async throws -> Bool {
		if recordedSessionIdsForPreview.contains(uuid) {
			return true
		}
		if deletedSampleSessionIds.contains(uuid) {
			return false
		}
		return Self.sampleSessions.contains { $0.id == uuid }
	}

	func fetchRecordingSession(uuid: UUID) async throws -> SingingSession {
		if deletedSampleSessionIds.contains(uuid) {
			throw SessionRepositoryError.sessionNotFound(uuid)
		}
		guard let session = Self.sampleSessions.first(where: { $0.id == uuid }) else {
			throw SessionRepositoryError.sessionNotFound(uuid)
		}
		return session
	}

	private static let sampleSessions: [SingingSession] = {
		let t1 = Track(userEnteredName: "アイドル")
		let t2 = Track(userEnteredName: "怪獣の花唄")
		let t3 = Track(userEnteredName: "Subtitle")

		return [
			SingingSession(
				id: sampleId1,
				track: t1,
				intent: .shout,
				performedAt: .now.addingTimeInterval(-3600),
				score: 92.5
			),
			SingingSession(
				id: sampleId2,
				track: t2,
				intent: .practice,
				performedAt: .now.addingTimeInterval(-7200),
				score: 88.0
			),
			SingingSession(
				id: sampleId3,
				track: t3,
				intent: .emo,
				performedAt: .now.addingTimeInterval(-10800),
				score: 94.2
			),
		]
	}()
}
