import Foundation

@MainActor
final class PreviewTrackRepository: TrackRepositoryProtocol {
	/// 環境キーの初期値として、メインアクターの外で作られることがあるため（ADR 0027）。
	nonisolated init() {}

	func searchLocal(query: String) async throws -> [Track] {
		[]
	}

	func searchLocalByArtist(query: String) async throws -> [Track] {
		[]
	}

	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?, userEnteredArtistName: String?) async throws -> Track {
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

		return Track(userEnteredName: trimmedUserName ?? "Preview Track", userEnteredArtistName: userEnteredArtistName)
	}

	func fillArtistName(_ artistName: String, trackId: UUID) async throws -> Track {
		Track(id: trackId, userEnteredName: "Preview Track", userEnteredArtistName: artistName)
	}

	func updateArtistName(_ artistName: String, trackId: UUID) async throws -> ArtistNameUpdateResult {
		.updated(Track(id: trackId, userEnteredName: "Preview Track", userEnteredArtistName: artistName))
	}

	func mergeTrack(_ sourceId: UUID, into targetId: UUID) async throws -> Track {
		Track(id: targetId, userEnteredName: "Preview Track")
	}

	func incrementSingCount(trackId: UUID) async throws {
		// no-op
	}
}

