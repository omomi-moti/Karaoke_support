import Foundation

enum TrackResolveError: Error {
	case emptyManualName
	/// 正規化後も Spotify ID と手動曲名のどちらも無効（例: `.localTrack` で両方空）。
	case invalidSelectedTrack
}

struct TrackResolver: Sendable {
	static func resolveSelectedTrack(from state: TrackInputState) throws -> SelectedTrack {
		switch state.mode {
		case .manual:
			guard let name = state.normalizedManualName else {
				throw TrackResolveError.emptyManualName
			}
			guard let selected = SelectedTrack(spotifyTrackId: nil, userEnteredName: name) else {
				throw TrackResolveError.invalidSelectedTrack
			}
			return selected

		case .spotifyHistory(let spotifyTrackId, _):
			guard let selected = SelectedTrack(spotifyTrackId: spotifyTrackId, userEnteredName: nil) else {
				throw TrackResolveError.invalidSelectedTrack
			}
			return selected

		case .localTrack(_, let spotifyTrackId, let userEnteredName):
			guard let selected = SelectedTrack(spotifyTrackId: spotifyTrackId, userEnteredName: userEnteredName) else {
				throw TrackResolveError.invalidSelectedTrack
			}
			return selected
		}
	}
}
