import Foundation

/// 歌唱セッションの永続化・取得を担当する Repository のプロトコル。
/// `@MainActor` の実装はもともと Sendable なので、Sendable を契約に入れて `any` 越しにも安全に共有できるようにする（ADR 0027）。
@MainActor
protocol SessionRepositoryProtocol: Sendable {
	func saveNewRecordingSession(_ session: SingingSession) async throws
    
	func updateRecordingSession(_ session: SingingSession) async throws

	func deleteRecordingSession(uuid: UUID) async throws

	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession]

	func fetchByIntent(_ intent: Intent, limit: Int, offset: Int) async throws -> [SingingSession]

	func fetchByIntent(_ intent: Intent) async throws -> [SingingSession]

	func exists(uuid: UUID) async throws -> Bool

	func fetchRecordingSession(uuid: UUID) async throws -> SingingSession

	/// `performedAt` 昇順（他の fetch と逆）。Track が無ければ空配列。
	func fetchSessions(trackId: UUID) async throws -> [SingingSession]
}

extension SessionRepositoryProtocol {
	func fetchByIntent(_ intent: Intent) async throws -> [SingingSession] {
		try await fetchByIntent(intent, limit: SessionRecentWindow.maxSessionCount, offset: 0)
	}
}
