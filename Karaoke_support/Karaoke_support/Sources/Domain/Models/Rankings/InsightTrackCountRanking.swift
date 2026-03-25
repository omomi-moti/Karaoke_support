//
//  InsightTrackCountRanking.swift
//  Karaoke_support
//

import Foundation

/// Track 単位の回数ランキング項目。
struct InsightTrackCountRanking: Identifiable {
	/// Track の永続ID。
	let id: UUID
	let trackId: UUID
	let spotifyTrackId: String?
	let userEnteredName: String?
	/// ランキング集計値（期間/intent で集計したセッション数）。
	let countInPeriod: Int

	/// 選曲記録フローへ渡す（少なくとも片方は非空になる想定）。
	func makeSelectedTrack() -> SelectedTrack? {
		SelectedTrack(spotifyTrackId: spotifyTrackId, userEnteredName: userEnteredName)
	}
}

