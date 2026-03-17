//
//  InsightTrackCountRanking.swift
//  Karaoke_support
//

import Foundation

/// Track 単位の回数ランキング項目。
struct InsightTrackCountRanking: Identifiable {
	let id: UUID
	let track: Track
	let singCount: Int
}

