//
//  MyAnthemRanking.swift
//  Karaoke_support
//

import Foundation

/// Intent 別のランキングセット。
struct MyAnthemRanking: Identifiable {
	var id: Intent { intent }
	let intent: Intent
	let byCount: [InsightTrackCountRanking]
	let byScore: [InsightTrackScoreRanking]
}

