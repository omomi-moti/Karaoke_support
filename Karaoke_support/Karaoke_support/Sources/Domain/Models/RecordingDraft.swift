import Foundation

/// 記録シートの入力状態（UI用DTO）。
struct RecordingDraft: Equatable, Sendable {
	var score: Double = 92.5
	var intent: Intent = .shout
	var memo: String = ""

	var normalizedMemo: String? {
		let trimmed = memo.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}
}

