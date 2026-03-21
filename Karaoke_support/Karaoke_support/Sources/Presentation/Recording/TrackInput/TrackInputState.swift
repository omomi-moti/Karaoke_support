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
}

