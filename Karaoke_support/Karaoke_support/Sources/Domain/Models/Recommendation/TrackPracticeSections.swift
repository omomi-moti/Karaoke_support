import Foundation

/// 選曲画面の Practice に並べる挑戦中の曲（#131）。1 つの曲は、どちらか一方にだけ入る。今日歌った曲も入る。
struct TrackPracticeSections: Equatable, Sendable {
	/// 「練習中の曲」：最新の記録の気分が Practice で、歌い切れた曲。
	let practicing: [TrackRecommendation]
	/// 「歌い切れなかった曲」：最新の記録で歌い切れなかった曲。気分は問わない。
	let unfinished: [TrackRecommendation]

	var isEmpty: Bool { practicing.isEmpty && unfinished.isEmpty }
}
