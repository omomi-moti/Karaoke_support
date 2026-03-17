//
//  InsightRepositoryProtocol.swift
//  Karaoke_support
//
//  I-005: InsightRepository のプロトコル。SwiftData の具体実装に依存しない。
//

import Foundation

/// インサイト（ランキング等）の取得を担当する Repository のプロトコル。
@MainActor
protocol InsightRepositoryProtocol {
	/// 過去 1 ヶ月の歌唱回数ランキング（Track 単位）。
	func fetchTimeMachineRanking() async throws -> [InsightTrackCountRanking]

	/// Intent 別の「歌った回数ランキング」「点数ランキング」を取得する。
	func fetchMyAnthemRankings() async throws -> [MyAnthemRanking]
}

