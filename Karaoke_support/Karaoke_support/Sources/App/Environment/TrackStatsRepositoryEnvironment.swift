import SwiftUI

private struct TrackStatsRepositoryEnvironmentKey: EnvironmentKey {
	/// 初期値は状態を持つ参照型なので、@Entry ではなく static let で 1 回だけ作る（ADR 0031）。
	static let defaultValue: any TrackStatsRepositoryProtocol = PreviewTrackStatsRepository()
}

extension EnvironmentValues {
	var trackStatsRepository: any TrackStatsRepositoryProtocol {
		get { self[TrackStatsRepositoryEnvironmentKey.self] }
		set { self[TrackStatsRepositoryEnvironmentKey.self] = newValue }
	}
}
