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
		/// SwiftData の `#Predicate` は `Intent` の `rawValue` 比較も `Intent.shout` 等の列挙比較もサポートしない（スキーマ／マクロ制約）。
		/// 日時降順で取得し、メモリ上で `intent` を絞り込む（I-014）。大量データ時は I-015 や `intent` の String 永続化＋Predicate を検討。
		var descriptor = FetchDescriptor<SingingSession>(
			sortBy: [SortDescriptor(\.performedAt, order: .reverse)]
		)
		let rows = try modelContext.fetch(descriptor)
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
}
