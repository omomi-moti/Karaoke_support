import Foundation

/// 選曲画面に並べる候補。1 つの曲は、どちらか一方のセクションにだけ入る。
struct TrackSelectionSections: Equatable, Sendable {
	/// 「また歌いたい」：最新の記録にハートが付いた曲。今の気分と違う曲も入る。
	let wantAgain: [TrackRecommendation]
	/// 「今の気分に合う曲」：ハートがなく、最新の記録の気分が今の気分と同じ曲。
	let moodMatched: [TrackRecommendation]

	var isEmpty: Bool { wantAgain.isEmpty && moodMatched.isEmpty }
}
