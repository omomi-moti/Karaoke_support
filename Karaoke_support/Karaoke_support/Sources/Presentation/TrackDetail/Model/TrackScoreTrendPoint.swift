import Foundation

/// 曲詳細の表示専用スナップショット。SwiftData の ``SingingSession`` を取得直後に値へ写す。
struct TrackScoreTrendPoint: Identifiable, Equatable {
	let id: UUID
	/// 1 始まりの歌唱回数。グラフの X 軸。
	let order: Int
	let performedAt: Date
	let intent: Intent
	let score: Double

	init(id: UUID, order: Int, performedAt: Date, intent: Intent, score: Double) {
		self.id = id
		self.order = order
		self.performedAt = performedAt
		self.intent = intent
		self.score = score
	}

	init(order: Int, mapping session: SingingSession) {
		self.init(
			id: session.id,
			order: order,
			performedAt: session.performedAt,
			intent: session.intent,
			score: session.score
		)
	}
}
