import Foundation

/// 歌唱記録画面を開くときの初期状態（I-013）。
enum RecordingSessionSeed: Equatable {
	/// ``TrackInputMode`` に従う（手動・Spotify 表示など）。
	case mode(TrackInputMode)
	/// 既に確定した ``SelectedTrack``（ランキングタップ・検索など）。
	case selectedTrack(SelectedTrack)
}
