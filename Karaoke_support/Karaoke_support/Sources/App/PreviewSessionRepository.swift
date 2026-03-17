import Foundation

@MainActor
final class PreviewSessionRepository: SessionRepositoryProtocol {
	func save(session: SingingSession) async throws {
		// no-op
	}

	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession] {
		[]
	}

	func fetchByIntent(_ intent: Intent) async throws -> [SingingSession] {
		[]
	}

	func exists(uuid: UUID) async throws -> Bool {
		false
	}
}

