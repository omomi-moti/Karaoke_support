import Foundation

/// V1 の曲名表示。V2 で ``TrackMetadataCache`` 等に差し替える際は呼び出しをこの型に集約すると変更が局所化される（I-014）。
enum TrackDisplayTitle {
	/// 一覧・行の主タイトル。手動曲名優先、なければ Spotify ID の短縮、いずれもなければ「不明」。
	static func primary(for track: Track) -> String {
		if let name = track.userEnteredName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			return name
		}
		if let sid = track.spotifyTrackId, !sid.isEmpty {
			return Self.shortenedSpotifyDisplayId(sid)
		}
		return "不明"
	}

	/// `spotify:track:...` のような URI は **最後の `:` 以降（実体 ID）** を表示対象にする。先頭 16 文字だけ切ると `spotify:track:` で固定になり識別できないため。
	static func shortenedSpotifyDisplayId(_ sid: String) -> String {
		let coreId: String
		if let lastColon = sid.lastIndex(of: ":") {
			let afterColon = sid.index(after: lastColon)
			coreId = afterColon < sid.endIndex ? String(sid[afterColon...]) : ""
		} else {
			coreId = sid
		}
		if coreId.isEmpty {
			return Self.fallbackShortenWholeString(sid)
		}
		if coreId.count > 16 {
			return String(coreId.prefix(16)) + "…"
		}
		return coreId
	}

	private static func fallbackShortenWholeString(_ sid: String) -> String {
		if sid.count > 16 {
			return String(sid.prefix(16)) + "…"
		}
		return sid
	}
}
