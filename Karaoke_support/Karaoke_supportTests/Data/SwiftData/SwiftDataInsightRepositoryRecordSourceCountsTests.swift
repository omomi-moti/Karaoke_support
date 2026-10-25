import Foundation
import SwiftData
import Testing

@testable import Karaoke_support

@Suite("SwiftDataInsightRepository.fetchRecordSourceCounts()")
@MainActor
struct SwiftDataInsightRepositoryRecordSourceCountsTests {

	private let context: ModelContext
	private let repository: SwiftDataInsightRepository

	init() throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		context = ModelContext(container)
		repository = SwiftDataInsightRepository(modelContext: context)
	}

	@Test("記録がなければ 0 ／ 0")
	func zeroWhenEmpty() async throws {
		let counts = try await repository.fetchRecordSourceCounts()
		#expect(counts == RecordSourceCounts(suggestion: 0, recorded: 0))
	}

	@Test("提案から付けた数と、記録の数を数える")
	func countsSuggestionAndRecorded() async throws {
		let track = Track(userEnteredName: "数える曲")
		context.insert(track)
		context.insert(SingingSession(track: track, intent: .shout, score: nil, source: .suggestion))
		context.insert(SingingSession(track: track, intent: .emo, score: 90, source: .suggestion))
		context.insert(SingingSession(track: track, intent: .practice, score: nil, source: .manual))
		try context.save()

		let counts = try await repository.fetchRecordSourceCounts()

		#expect(counts == RecordSourceCounts(suggestion: 2, recorded: 3))
	}
}
