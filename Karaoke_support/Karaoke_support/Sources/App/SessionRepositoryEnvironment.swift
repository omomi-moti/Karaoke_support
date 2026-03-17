import SwiftUI

private struct SessionRepositoryEnvironmentKey: EnvironmentKey {
	@MainActor static let defaultValue: any SessionRepositoryProtocol = PreviewSessionRepository()
}

public extension EnvironmentValues {
	var sessionRepository: any SessionRepositoryProtocol {
		get { self[SessionRepositoryEnvironmentKey.self] }
		set { self[SessionRepositoryEnvironmentKey.self] = newValue }
	}
}

