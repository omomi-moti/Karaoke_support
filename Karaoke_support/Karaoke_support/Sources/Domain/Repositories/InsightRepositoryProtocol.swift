//
//  InsightRepositoryProtocol.swift
//  Karaoke_support
//
//  I-005: InsightRepository のプロトコル。SwiftData の具体実装に依存しない。
//

import Foundation

/// 記録の集計の取得を担当する Repository のプロトコル。
/// `@MainActor` の実装はもともと Sendable なので、Sendable を契約に入れて `any` 越しにも安全に共有できるようにする（ADR 0027）。
@MainActor
protocol InsightRepositoryProtocol: Sendable {
	/// 入口を記録し始めてから付けた記録の数と、そのうち提案から付けた数（#120）。
	func fetchRecordSourceCounts() async throws -> RecordSourceCounts
}
