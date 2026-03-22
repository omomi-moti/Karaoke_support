//
//  SwiftDataSessionRepository.swift
//  Karaoke_support
//
//  I-003: SessionRepository の SwiftData 実装。
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataSessionRepository: SessionRepositoryProtocol {
	private let modelContext: ModelContext

	init(modelContext: ModelContext) {
		self.modelContext = modelContext
	}

	/// I-011: 同一 ``SingingSession.id`` の再試行は insert / singCount 更新をスキップして冪等にする。
	func saveNewRecordingSession(_ session: SingingSession) async throws {
		if try await exists(uuid: session.id) {
			return
		}
		modelContext.insert(session)
		session.track.singCount += 1
		session.track.updatedAt = .now
		try modelContext.save()
	}

	func updateRecordingSession(_ session: SingingSession) async throws {
		let idToMatch = session.id
		var descriptor = FetchDescriptor<SingingSession>(
			predicate: #Predicate<SingingSession> { $0.id == idToMatch }
		)
		descriptor.fetchLimit = 1
		guard let existing = try modelContext.fetch(descriptor).first else {
			throw SessionRepositoryError.sessionNotFound(idToMatch)
		}
		guard existing.track.id == session.track.id else {
			throw SessionRepositoryError.sessionUpdateTrackChangeNotSupported
		}
		existing.intent = session.intent
		existing.performedAt = session.performedAt
		existing.score = session.score
		existing.memo = session.memo
		existing.track.updatedAt = .now
		try modelContext.save()
	}

	func deleteRecordingSession(uuid: UUID) async throws {
		let idToMatch = uuid
		var descriptor = FetchDescriptor<SingingSession>(
			predicate: #Predicate<SingingSession> { $0.id == idToMatch }
		)
		descriptor.fetchLimit = 1
		guard let existing = try modelContext.fetch(descriptor).first else {
			throw SessionRepositoryError.sessionNotFound(idToMatch)
		}
		let track = existing.track
		track.singCount = max(0, track.singCount - 1)
		track.updatedAt = .now
		modelContext.delete(existing)
		try modelContext.save()
	}

	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession] {
		guard limit >= 0, offset >= 0 else {
			throw SessionRepositoryError.invalidParameter("limit and offset must be non-negative")
		}
		var descriptor = FetchDescriptor<SingingSession>(
			sortBy: [SortDescriptor(\.performedAt, order: .reverse)]
		)
		descriptor.fetchLimit = limit
		descriptor.fetchOffset = offset
		return try modelContext.fetch(descriptor)
	}

	func fetchByIntent(_ intent: Intent) async throws -> [SingingSession] {
		// `fetchAll` と同一の直近ウィンドウに揃え、無制限フェッチを避ける（履歴 VM と同じ戦略）。
		let rows = try await fetchAll(limit: SessionRecentWindow.maxSessionCount, offset: 0)
		return rows.filter { $0.intent == intent }
	}

	func exists(uuid: UUID) async throws -> Bool {
		let idToMatch = uuid
		var descriptor = FetchDescriptor<SingingSession>(
			predicate: #Predicate<SingingSession> { $0.id == idToMatch }
		)
		descriptor.fetchLimit = 1
		let results = try modelContext.fetch(descriptor)
		return !results.isEmpty
	}

	func fetchRecordingSession(uuid: UUID) async throws -> SingingSession {
		let idToMatch = uuid
		var descriptor = FetchDescriptor<SingingSession>(
			predicate: #Predicate<SingingSession> { $0.id == idToMatch }
		)
		descriptor.fetchLimit = 1
		guard let session = try modelContext.fetch(descriptor).first else {
			throw SessionRepositoryError.sessionNotFound(uuid)
		}
		return session
	}
}
