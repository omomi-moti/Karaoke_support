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
		let cutoff = try InsightPeriod.oneMonth.cutoffDate()

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
			.map {
				let track = $0.track
				return InsightTrackCountRanking(
					id: track.id,
					trackId: track.id,
					spotifyTrackId: track.spotifyTrackId,
					userEnteredName: track.userEnteredName,
					countInPeriod: $0.count
				)
			}
	}

	func fetchMyAnthemRankings(period: InsightPeriod) async throws -> [MyAnthemRanking] {
		let cutoff = try period.cutoffDate()

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
		// 点数なしの記録は回数には数えるが、最高点には使わない。点数ありが 1 件も無い曲は bestScore が nil
		var aggregatesByTrackId: [UUID: (track: Track, count: Int, bestScore: Double?)] = [:]
		for session in sessions {
			let track = session.track
			let id = track.id
			if let existing = aggregatesByTrackId[id] {
				aggregatesByTrackId[id] = (
					track: existing.track,
					count: existing.count + 1,
					bestScore: [existing.bestScore, session.score].compactMap { $0 }.max()
				)
			} else {
				aggregatesByTrackId[id] = (track: track, count: 1, bestScore: session.score)
			}
		}

		let byCount = aggregatesByTrackId.values
			.sorted { $0.count > $1.count }
			.map {
				let track = $0.track
				return InsightTrackCountRanking(
					id: track.id,
					trackId: track.id,
					spotifyTrackId: track.spotifyTrackId,
					userEnteredName: track.userEnteredName,
					countInPeriod: $0.count
				)
			}

		// 点数ランキングには点数ありの記録がある曲だけを並べる
		let byScore = aggregatesByTrackId.values
			.compactMap { aggregate in aggregate.bestScore.map { (track: aggregate.track, bestScore: $0) } }
			.sorted { $0.bestScore > $1.bestScore }
			.map {
				let track = $0.track
				return InsightTrackScoreRanking(
					id: track.id,
					trackId: track.id,
					spotifyTrackId: track.spotifyTrackId,
					userEnteredName: track.userEnteredName,
					bestScore: $0.bestScore
				)
			}

		return MyAnthemRanking(intent: intent, byCount: byCount, byScore: byScore)
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
