import SwiftUI

private struct InsightRepositoryEnvironmentKey: EnvironmentKey {
	@MainActor static let defaultValue: any InsightRepositoryProtocol = PreviewInsightRepository()
}

extension EnvironmentValues {
	var insightRepository: any InsightRepositoryProtocol {
		get { self[InsightRepositoryEnvironmentKey.self] }
		set { self[InsightRepositoryEnvironmentKey.self] = newValue }
	}
}

