import Foundation

/// 選曲タブから記録画面へ進むルート（I-013）。表示は `NavigationStack` の push ではなくシートで行い、保存後の「ポップでルートが一瞬見える」を避ける。
enum SongsRecordingRoute: Hashable, Identifiable {
	/// 手動で曲名を入力してから Intent・スコアへ（従来の手動フロー）。
	case manualRecording
	/// 確定済みの曲から記録（タイムマシン等のランキングタップ・V2 の検索から同型で利用）。
	case recording(SelectedTrack)

	var id: String {
		switch self {
		case .manualRecording:
			return "manualRecording"
		case .recording(let track):
			let sp = track.spotifyTrackId ?? ""
			let name = track.userEnteredName ?? ""
			return "recording|\(sp)|\(name)"
		}
	}
}
