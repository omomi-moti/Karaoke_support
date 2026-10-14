import Foundation
import SwiftData
import Testing

@testable import Karaoke_support

@Suite("SwiftDataInsightRepository 点数なしの記録")
@MainActor
struct SwiftDataInsightRepositoryMissingScoreTests {

	private let context: ModelContext
	private let repository: SwiftDataInsightRepository

	init() throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		context = ModelContext(container)
		repository = SwiftDataInsightRepository(modelContext: context)
	}

	private func insertSession(track: Track, score: Double?) {
		context.insert(SingingSession(track: track, intent: .shout, performedAt: .now, score: score))
	}

	private func shoutRanking() async throws -> MyAnthemRanking {
		let rankings = try await repository.fetchMyAnthemRankings(period: .threeMonths)
		return try #require(rankings.first { $0.intent == .shout })
	}

	@Test("最高点は点数ありの記録だけで求め、回数は点数なしも数える")
	func bestScoreIgnoresMissingScores() async throws {
		let track = Track(userEnteredName: "混在")
		context.insert(track)
		insertSession(track: track, score: 70)
		insertSession(track: track, score: nil)
		try context.save()

		let ranking = try await shoutRanking()

		#expect(ranking.byCount.first?.countInPeriod == 2)
		#expect(ranking.byScore.map(\.bestScore) == [70])
	}

	@Test("点数ありの記録が 1 件も無い曲は、点数ランキングに出さない")
	func trackWithoutAnyScoreIsExcludedFromScoreRanking() async throws {
		let scored = Track(userEnteredName: "点数あり")
		let unscored = Track(userEnteredName: "点数なし")
		context.insert(scored)
		context.insert(unscored)
		insertSession(track: scored, score: 85)
		insertSession(track: unscored, score: nil)
		try context.save()

		let ranking = try await shoutRanking()

		#expect(ranking.byCount.count == 2)
		#expect(ranking.byScore.map(\.userEnteredName) == ["点数あり"])
	}
}
