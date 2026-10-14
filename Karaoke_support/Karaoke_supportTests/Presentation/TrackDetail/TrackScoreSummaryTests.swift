import Foundation
import Testing

@testable import Karaoke_support

@Suite("TrackScoreSummary")
struct TrackScoreSummaryTests {

	private func makePoint(order: Int, score: Double?) -> TrackScoreTrendPoint {
		TrackScoreTrendPoint(
			id: UUID(),
			order: order,
			performedAt: Date(timeIntervalSince1970: Double(order) * 100),
			intent: .shout,
			score: score
		)
	}

	@Test("0 件では nil を返す")
	func returnsNilForEmptyPoints() {
		#expect(TrackScoreSummary(points: []) == nil)
	}

	@Test("回数・平均・最高を計算する")
	func computesCountAverageAndBest() throws {
		let points = [
			makePoint(order: 1, score: 80),
			makePoint(order: 2, score: 90),
			makePoint(order: 3, score: 85),
		]

		let summary = try #require(TrackScoreSummary(points: points))
		#expect(summary.count == 3)
		#expect(summary.averageScore == 85)
		#expect(summary.bestScore == 90)
	}

	@Test("直近スコアと前回差を持つ")
	func exposesLatestScoreAndDelta() throws {
		let points = [
			makePoint(order: 1, score: 80),
			makePoint(order: 2, score: 90),
			makePoint(order: 3, score: 85),
		]

		let summary = try #require(TrackScoreSummary(points: points))
		#expect(summary.latestScore == 85)
		#expect(summary.deltaFromPrevious == -5)
	}

	@Test("1 件では前回差が nil になる")
	func singlePointHasNoDelta() throws {
		let summary = try #require(TrackScoreSummary(points: [makePoint(order: 1, score: 72.5)]))
		#expect(summary.latestScore == 72.5)
		#expect(summary.deltaFromPrevious == nil)
	}

	@Test("1 件では平均と最高が同じ値になる")
	func singlePointHasEqualAverageAndBest() throws {
		let summary = try #require(TrackScoreSummary(points: [makePoint(order: 1, score: 72.5)]))
		#expect(summary.count == 1)
		#expect(summary.averageScore == 72.5)
		#expect(summary.bestScore == 72.5)
	}

	// MARK: 点数なしの記録

	@Test("回数は点数なしも数え、平均・最高は点数ありだけで求める")
	func missingScoresAreCountedButNotAveraged() throws {
		let points = [
			makePoint(order: 1, score: 80),
			makePoint(order: 2, score: nil),
			makePoint(order: 3, score: 90),
		]

		let summary = try #require(TrackScoreSummary(points: points))
		#expect(summary.count == 3)
		#expect(summary.averageScore == 85)
		#expect(summary.bestScore == 90)
	}

	@Test("直近スコアと前回差は、点数ありの記録どうしで求める")
	func latestAndDeltaSkipMissingScores() throws {
		let points = [
			makePoint(order: 1, score: 80),
			makePoint(order: 2, score: 90),
			makePoint(order: 3, score: nil),  // いちばん新しい記録は点数なし
		]

		let summary = try #require(TrackScoreSummary(points: points))
		#expect(summary.latestScore == 90)
		#expect(summary.deltaFromPrevious == 10)
	}

	@Test("点数ありが 1 件も無ければ、回数だけ持ち点数の統計は nil")
	func allMissingScoresHaveNoScoreStats() throws {
		let summary = try #require(TrackScoreSummary(points: [makePoint(order: 1, score: nil), makePoint(order: 2, score: nil)]))
		#expect(summary.count == 2)
		#expect(summary.averageScore == nil)
		#expect(summary.bestScore == nil)
		#expect(summary.latestScore == nil)
		#expect(summary.deltaFromPrevious == nil)
	}
}
