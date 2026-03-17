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

	func save(session: SingingSession) async throws {
		modelContext.insert(session)
		try modelContext.save()
	}

	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession] {
		var descriptor = FetchDescriptor<SingingSession>(
			sortBy: [SortDescriptor(\.performedAt, order: .reverse)]
		)
		descriptor.fetchLimit = limit
		descriptor.fetchOffset = offset
		return try modelContext.fetch(descriptor)
	}

	func fetchByIntent(_ intent: Intent) async throws -> [SingingSession] {
		let intentToMatch = intent
		var descriptor = FetchDescriptor<SingingSession>(
			predicate: #Predicate<SingingSession> { session in
				session.intent == intentToMatch
			},
			sortBy: [SortDescriptor(\.performedAt, order: .reverse)]
		)
		return try modelContext.fetch(descriptor)
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
}
