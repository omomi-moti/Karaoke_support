import Foundation

/// 記録シートで保存した記録の要約。保存直後のシートに渡す（#115）。
struct SavedRecording: Equatable, Sendable {
	let sessionId: UUID
	let trackId: UUID
	/// 表示用の曲名（``TrackDisplayTitle/primary(for:)``）。
	let trackTitle: String
	let intent: Intent
	let score: Double?
	/// 新規の記録なら `true`、編集して更新した記録なら `false`。
	let isNewRecording: Bool
}
