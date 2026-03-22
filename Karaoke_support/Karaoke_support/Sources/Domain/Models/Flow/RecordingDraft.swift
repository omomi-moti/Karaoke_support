import Foundation

/// 記録シートの入力状態（UI用DTO）。
struct RecordingDraft: Equatable, Sendable {
	var score: Double = 92.5
	var intent: Intent = .shout
	var memo: String = ""
	/// 歌唱日時（新規・編集とも保存時に ``SingingSession/performedAt`` に反映）。
	var performedAt: Date = Date()

	var normalizedMemo: String? {
		let trimmed = memo.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}
}

