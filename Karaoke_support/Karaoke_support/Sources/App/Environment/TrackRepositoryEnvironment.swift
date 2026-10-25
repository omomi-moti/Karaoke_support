import SwiftUI

private struct TrackRepositoryEnvironmentKey: EnvironmentKey {
	/// 初期値は状態を持つ参照型なので、@Entry ではなく static let で 1 回だけ作る（ADR 0031）。
	static let defaultValue: any TrackRepositoryProtocol = PreviewTrackRepository()
}

extension EnvironmentValues {
	var trackRepository: any TrackRepositoryProtocol {
		get { self[TrackRepositoryEnvironmentKey.self] }
		set { self[TrackRepositoryEnvironmentKey.self] = newValue }
	}
}

