import Foundation

enum TrackResolveError: Error {
	case emptyManualName
}

struct TrackResolver: Sendable {
	static func resolveSelectedTrack(from state: TrackInputState) throws -> SelectedTrack {
		switch state.mode {
		case .manual:
			guard let name = state.normalizedManualName else {
				throw TrackResolveError.emptyManualName
			}
			return SelectedTrack(spotifyTrackId: nil, userEnteredName: name)

		case .spotifyHistory(let spotifyTrackId, _):
			return SelectedTrack(spotifyTrackId: spotifyTrackId, userEnteredName: nil)

		case .localTrack(_, let spotifyTrackId, let userEnteredName):
			return SelectedTrack(spotifyTrackId: spotifyTrackId, userEnteredName: userEnteredName)
		}
	}
}

