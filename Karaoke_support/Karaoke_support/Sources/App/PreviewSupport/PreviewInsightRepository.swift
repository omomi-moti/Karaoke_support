import Foundation

@MainActor
final class PreviewInsightRepository: InsightRepositoryProtocol {
	/// 環境キーの初期値として、メインアクターの外で作られることがあるため（ADR 0027）。
	nonisolated init() {}

	func fetchRecordSourceCounts() async throws -> RecordSourceCounts {
		RecordSourceCounts(suggestion: 3, recorded: 10)
	}
}

