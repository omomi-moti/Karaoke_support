//
//  InsightTrackCountRanking.swift
//  Karaoke_support
//

import Foundation

/// Track 単位の回数ランキング項目。
struct InsightTrackCountRanking: Identifiable {
	let id: UUID
	let track: Track
	/// ランキング集計値（期間/intent で集計したセッション数）。
	let countInPeriod: Int
}

