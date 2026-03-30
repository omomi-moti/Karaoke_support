import SwiftUI

private struct TrackRepositoryEnvironmentKey: EnvironmentKey {
	@MainActor static let defaultValue: any TrackRepositoryProtocol = PreviewTrackRepository()
}

extension EnvironmentValues {
	var trackRepository: any TrackRepositoryProtocol {
		get { self[TrackRepositoryEnvironmentKey.self] }
		set { self[TrackRepositoryEnvironmentKey.self] = newValue }
	}
}

