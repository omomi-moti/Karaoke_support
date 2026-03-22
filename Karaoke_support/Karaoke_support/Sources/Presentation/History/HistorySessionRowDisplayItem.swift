import Foundation

/// 履歴一覧の **表示専用** スナップショット。
///
/// List の行に ``SingingSession``（SwiftData）を直接渡すと、削除後も SwiftUI が一瞬古い参照を描画し
/// `intent` 等の fault で fatal になりうるため、Repository から取得した直後に値だけをコピーして保持する。
struct HistorySessionRowDisplayItem: Identifiable, Equatable {
	let id: UUID
	let intent: Intent
	let trackPrimaryTitle: String
	let performedAt: Date
	let score: Double

	init(
		id: UUID,
		intent: Intent,
		trackPrimaryTitle: String,
		performedAt: Date,
		score: Double
	) {
		self.id = id
		self.intent = intent
		self.trackPrimaryTitle = trackPrimaryTitle
		self.performedAt = performedAt
		self.score = score
	}

	init(mapping session: SingingSession) {
		self.init(
			id: session.id,
			intent: session.intent,
			trackPrimaryTitle: TrackDisplayTitle.primary(for: session.track),
			performedAt: session.performedAt,
			score: session.score
		)
	}
}
