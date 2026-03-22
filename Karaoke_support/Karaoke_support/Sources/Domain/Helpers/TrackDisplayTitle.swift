import Foundation

/// V1 の曲名表示。V2 で ``TrackMetadataCache`` 等に差し替える際は呼び出しをこの型に集約すると変更が局所化される（I-014）。
enum TrackDisplayTitle {
	/// 一覧・行の主タイトル。手動曲名優先、なければ Spotify ID の短縮、いずれもなければ「不明」。
	static func primary(for track: Track) -> String {
		if let name = track.userEnteredName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			return name
		}
		if let sid = track.spotifyTrackId, !sid.isEmpty {
			if sid.count > 16 {
				return String(sid.prefix(16)) + "…"
			}
			return sid
		}
		return "不明"
	}
}
