import Foundation

struct TrackInputState: Sendable, Equatable {
	var mode: TrackInputMode
	var manualName: String = ""
	var validationMessage: String? = nil

	var isEditable: Bool {
		if case .manual = mode { return true }
		return false
	}

	var displayName: String {
		switch mode {
		case .manual:
			return manualName
		case .spotifyHistory(_, let displayName):
			return displayName
		case .localTrack(_, _, let userEnteredName):
			return userEnteredName ?? ""
		}
	}

	var normalizedManualName: String? {
		let trimmed = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}

	/// 通常の曲入力（メンバーワイズの代わり。カスタム `init` 追加時に合成されなくなるため明示）。
	init(mode: TrackInputMode, manualName: String = "", validationMessage: String? = nil) {
		self.mode = mode
		self.manualName = manualName
		self.validationMessage = validationMessage
	}

	/// 既存 ``Track`` を差し替えず表示する編集用（曲は変更不可・I-014-C）。
	init(trackForEditingSession track: Track) {
		let display = TrackDisplayTitle.primary(for: track)
		if let sid = track.spotifyTrackId, !sid.isEmpty {
			self.init(mode: .spotifyHistory(spotifyTrackId: sid, displayName: display))
		} else if let name = track.userEnteredName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			self.init(mode: .manual, manualName: name)
		} else {
			self.init(mode: .manual)
		}
	}
}

