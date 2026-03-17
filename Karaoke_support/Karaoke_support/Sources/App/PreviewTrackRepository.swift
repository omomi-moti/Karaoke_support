import Foundation

@MainActor
final class PreviewTrackRepository: TrackRepositoryProtocol {
	func searchLocal(query: String) async throws -> [Track] {
		[]
	}

	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?) async throws -> Track {
		let trimmedSpotifyId = spotifyTrackId?.trimmingCharacters(in: .whitespacesAndNewlines)
		let trimmedUserName = userEnteredName?.trimmingCharacters(in: .whitespacesAndNewlines)

		let hasSpotifyId = !(trimmedSpotifyId?.isEmpty ?? true)
		let hasUserName = !(trimmedUserName?.isEmpty ?? true)
		guard hasSpotifyId || hasUserName else {
			throw TrackRepositoryError.bothIdsNil
		}

		if let sid = trimmedSpotifyId, !sid.isEmpty {
			return Track(spotifyTrackId: sid)
		}

		return Track(userEnteredName: trimmedUserName ?? "Preview Track")
	}

	func incrementSingCount(trackId: UUID) async throws {
		// no-op
	}
}

