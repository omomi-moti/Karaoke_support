import Foundation

/// 記録シートの入力状態（UI用DTO）。
struct RecordingDraft: Equatable, Sendable {
	/// 新規記録は未入力から始める。点数の入力は任意で、未入力のまま保存すると点数なしの記録になる。
	var score = ScoreDigitInput()
	var intent: Intent = .shout
	var memo: String = ""
	/// 歌唱日時。編集時のみ画面で直せて、保存時に ``SingingSession/performedAt`` に反映する。
	/// 新規記録では使わず、保存した時刻を歌唱日時にする（``RecordingSheetViewModel/save()``）。
	var performedAt: Date = Date()
	/// また歌いたいか（ハート）。新規記録は OFF から始める。
	var wantAgain = false
	/// 歌い切れたか。新規記録は「歌い切れた」から始める。
	var isCompleted = true

	var normalizedMemo: String? {
		let trimmed = memo.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}
}

