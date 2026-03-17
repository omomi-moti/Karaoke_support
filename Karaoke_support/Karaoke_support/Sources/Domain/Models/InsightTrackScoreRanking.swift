//
//  InsightTrackScoreRanking.swift
//  Karaoke_support
//

import Foundation

/// Track 単位のスコアランキング項目。
struct InsightTrackScoreRanking: Identifiable {
	let id: UUID
	let track: Track
	let bestScore: Double
}

