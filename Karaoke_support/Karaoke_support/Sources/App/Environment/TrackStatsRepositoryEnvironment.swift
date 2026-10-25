import SwiftUI

private struct TrackStatsRepositoryEnvironmentKey: EnvironmentKey {
	@MainActor static let defaultValue: any TrackStatsRepositoryProtocol = PreviewTrackStatsRepository()
}

extension EnvironmentValues {
	var trackStatsRepository: any TrackStatsRepositoryProtocol {
		get { self[TrackStatsRepositoryEnvironmentKey.self] }
		set { self[TrackStatsRepositoryEnvironmentKey.self] = newValue }
	}
}
