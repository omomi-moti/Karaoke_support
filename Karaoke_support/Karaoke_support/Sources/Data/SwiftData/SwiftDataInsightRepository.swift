//
//  SwiftDataInsightRepository.swift
//  Karaoke_support
//
//  I-005: InsightRepository の SwiftData 実装。
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataInsightRepository: InsightRepositoryProtocol {
	private let modelContext: ModelContext

	init(modelContext: ModelContext) {
		self.modelContext = modelContext
	}

	func fetchRecordSourceCounts() async throws -> RecordSourceCounts {
		// enum を含む #Predicate は使わず、全部読んでからメモリで数える（ADR 0007）
		let sessions = try modelContext.fetch(FetchDescriptor<SingingSession>())
		let recordedSources = sessions.compactMap(\.recordedSource)
		return RecordSourceCounts(
			suggestion: recordedSources.filter { $0 == .suggestion }.count,
			recorded: recordedSources.count
		)
	}
}
