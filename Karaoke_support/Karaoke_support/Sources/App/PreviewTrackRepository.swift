import Foundation

@MainActor
final class PreviewTrackRepository: TrackRepositoryProtocol {
	func searchLocal(query: String) async throws -> [Track] {
		[]
	}

	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?) async throws -> Track {
		throw TrackRepositoryError.bothIdsNil
	}

	func incrementSingCount(trackId: UUID) async throws {
		// no-op
	}
}

