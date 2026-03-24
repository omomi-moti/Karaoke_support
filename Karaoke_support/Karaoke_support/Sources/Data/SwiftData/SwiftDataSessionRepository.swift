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

	/// ``fetchByIntent(_:limit:offset:)`` 用: 直近ウィンドウを `fetchAll` したあと Intent で絞った列（offset>0 のスライスで再利用し、毎回のフルスキャンを避ける）。
	private var intentFilterCache: (intent: Intent, rows: [SingingSession])?

	init(modelContext: ModelContext) {
		self.modelContext = modelContext
	}

	private func invalidateIntentFilterCache() {
		intentFilterCache = nil
	}

	/// `offset + limit` が `Int` でオーバーフローしてもスライス終端を安全に得る。
	private func sliceEnd(offset: Int, limit: Int, count: Int) -> Int {
		let (sum, overflow) = offset.addingReportingOverflow(limit)
		let raw = overflow ? count : sum
		return min(raw, count)
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
		invalidateIntentFilterCache()
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
		invalidateIntentFilterCache()
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
		invalidateIntentFilterCache()
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

	func fetchByIntent(_ intent: Intent, limit: Int, offset: Int) async throws -> [SingingSession] {
		guard limit >= 0, offset >= 0 else {
			throw SessionRepositoryError.invalidParameter("limit and offset must be non-negative")
		}
		// SwiftData の `#Predicate` で Intent を安定して絞れないため、直近 ``SessionRecentWindow`` 件を取得してメモリ上で絞る。
		// offset==0 でウィンドウを取り直しキャッシュ更新。offset>0 は同一 intent のキャッシュをスライスして追加フェッチを避ける。
		let filtered: [SingingSession]
		if offset == 0 {
			let window = try await fetchAll(limit: SessionRecentWindow.maxSessionCount, offset: 0)
			let f = window.filter { $0.intent == intent }
			intentFilterCache = (intent, f)
			filtered = f
		} else if let cache = intentFilterCache, cache.intent == intent {
			filtered = cache.rows
		} else {
			let window = try await fetchAll(limit: SessionRecentWindow.maxSessionCount, offset: 0)
			let f = window.filter { $0.intent == intent }
			intentFilterCache = (intent, f)
			filtered = f
		}
		let start = min(offset, filtered.count)
		let end = sliceEnd(offset: offset, limit: limit, count: filtered.count)
		guard start < end else { return [] }
		return Array(filtered[start..<end])
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
