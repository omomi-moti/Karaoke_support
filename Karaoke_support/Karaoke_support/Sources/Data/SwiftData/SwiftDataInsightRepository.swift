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

	func fetchTimeMachineRanking() async throws -> [InsightTrackCountRanking] {
		guard let cutoff = Calendar.current.date(byAdding: .month, value: -1, to: .now) else {
			return []
		}

		let cutoffToMatch = cutoff
		let descriptor = FetchDescriptor<SingingSession>(
			predicate: #Predicate<SingingSession> { session in
				session.performedAt >= cutoffToMatch
			}
		)
		let sessions = try modelContext.fetch(descriptor)

		var countsByTrackId: [UUID: (track: Track, count: Int)] = [:]
		for session in sessions {
			let track = session.track
			let id = track.id
			if let existing = countsByTrackId[id] {
				countsByTrackId[id] = (track: existing.track, count: existing.count + 1)
			} else {
				countsByTrackId[id] = (track: track, count: 1)
			}
		}

		return countsByTrackId
			.values
			.sorted { $0.count > $1.count }
			.map { InsightTrackCountRanking(id: $0.track.id, track: $0.track, countInPeriod: $0.count) }
	}

	func fetchMyAnthemRankings(period: InsightPeriod) async throws -> [MyAnthemRanking] {
		guard let cutoff = period.cutoffDate() else {
			return []
		}

		let cutoffToMatch = cutoff
		let descriptor = FetchDescriptor<SingingSession>(
			predicate: #Predicate<SingingSession> { session in
				session.performedAt >= cutoffToMatch
			}
		)
		let allSessionsInPeriod = try modelContext.fetch(descriptor)

		let sessionsByIntent = Dictionary(grouping: allSessionsInPeriod, by: { $0.intent })
		return Intent.allCases.map { intent in
			let sessionsForIntent = sessionsByIntent[intent] ?? []
			return buildMyAnthemRanking(intent: intent, sessions: sessionsForIntent)
		}
	}

	// MARK: - Private

	private func buildMyAnthemRanking(intent: Intent, sessions: [SingingSession]) -> MyAnthemRanking {
		var aggregatesByTrackId: [UUID: (track: Track, count: Int, bestScore: Double)] = [:]
		for session in sessions {
			let track = session.track
			let id = track.id
			if let existing = aggregatesByTrackId[id] {
				aggregatesByTrackId[id] = (
					track: existing.track,
					count: existing.count + 1,
					bestScore: max(existing.bestScore, session.score)
				)
			} else {
				aggregatesByTrackId[id] = (track: track, count: 1, bestScore: session.score)
			}
		}

		let byCount = aggregatesByTrackId.values
			.sorted { $0.count > $1.count }
			.map { InsightTrackCountRanking(id: $0.track.id, track: $0.track, countInPeriod: $0.count) }

		let byScore = aggregatesByTrackId.values
			.sorted { $0.bestScore > $1.bestScore }
			.map { InsightTrackScoreRanking(id: $0.track.id, track: $0.track, bestScore: $0.bestScore) }

		return MyAnthemRanking(intent: intent, byCount: byCount, byScore: byScore)
	}
}

