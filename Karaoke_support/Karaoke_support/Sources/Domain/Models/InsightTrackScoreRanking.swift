//
//  InsightTrackScoreRanking.swift
//  Karaoke_support
//

import Foundation

/// Track 単位のスコアランキング項目。
struct InsightTrackScoreRanking: Identifiable {
	/// Track の永続ID。
	let id: UUID
	let trackId: UUID
	let spotifyTrackId: String?
	let userEnteredName: String?
	let bestScore: Double
}

