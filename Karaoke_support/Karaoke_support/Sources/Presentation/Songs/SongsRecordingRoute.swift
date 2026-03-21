import Foundation

/// 選曲タブ内 `NavigationPath` に載せるルート（I-013）。
enum SongsRecordingRoute: Hashable {
	/// 手動で曲名を入力してから Intent・スコアへ（従来の手動フロー）。
	case manualRecording
	/// 確定済みの曲から記録（タイムマシン等のランキングタップ・V2 の検索から同型で利用）。
	case recording(SelectedTrack)
}
