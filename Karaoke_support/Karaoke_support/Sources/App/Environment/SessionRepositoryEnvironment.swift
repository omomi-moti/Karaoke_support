import SwiftUI

private struct SessionRepositoryEnvironmentKey: EnvironmentKey {
	/// 初期値は状態を持つ参照型なので、@Entry ではなく static let で 1 回だけ作る（ADR 0031）。
	static let defaultValue: any SessionRepositoryProtocol = PreviewSessionRepository()
}

extension EnvironmentValues {
	var sessionRepository: any SessionRepositoryProtocol {
		get { self[SessionRepositoryEnvironmentKey.self] }
		set { self[SessionRepositoryEnvironmentKey.self] = newValue }
	}
}

