import SwiftUI

private struct InsightRepositoryEnvironmentKey: EnvironmentKey {
	/// 初期値は状態を持つ参照型なので、@Entry ではなく static let で 1 回だけ作る（ADR 0031）。
	static let defaultValue: any InsightRepositoryProtocol = PreviewInsightRepository()
}

extension EnvironmentValues {
	var insightRepository: any InsightRepositoryProtocol {
		get { self[InsightRepositoryEnvironmentKey.self] }
		set { self[InsightRepositoryEnvironmentKey.self] = newValue }
	}
}

