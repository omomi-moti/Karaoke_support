import Foundation

/// 保存直後のシートに出す中身（#115）。候補は必ず 1 件以上ある。
struct AfterSaveSheetContent: Equatable, Sendable {
	let saved: SavedRecording
	let recommendations: [TrackRecommendation]
}
