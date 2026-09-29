import Foundation

/// 記録シートの「もしかして」欄の表示状態。
enum TrackSuggestionState: Equatable, Sendable {
	/// 何も出さない（空入力・編集中・既存の曲名と完全一致・検索失敗）
	case hidden
	/// 検索したが、歌ったことがある曲に候補がない
	case noMatch
	/// 候補あり（1〜``RecordingSheetViewModel/maxTrackSuggestions`` 件）
	case suggestions([TrackSuggestion])
}
