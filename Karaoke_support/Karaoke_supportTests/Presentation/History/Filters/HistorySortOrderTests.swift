//
//  HistorySortOrderTests.swift
//  Karaoke_supportTests
//
//  I-014-B: `HistorySortOrder` の整列ルール（安定化キー含む）。
//

import XCTest

@testable import Karaoke_support

final class HistorySortOrderTests: XCTestCase {

	private var idLow: UUID!
	private var idHigh: UUID!

	override func setUpWithError() throws {
		try super.setUpWithError()
		idLow = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
		idHigh = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
	}

	/// 概要: .performedAtDescending ソートで、performedAt が新しいセッションが先頭に来ること
	/// 前提(Given): performedAt=100（古）と performedAt=200（新）の 2 件（スコアは同値）
	/// 実行(When): HistorySortOrder.performedAtDescending.sorted(_:) を呼ぶ
	/// 検証(Then): 返却配列の先頭が newer の id、末尾が older の id となる
	func testPerformedAtDescending_PutsNewerFirst() {
		let older = HistorySessionRowDisplayItem(
			id: idLow,
			intent: .shout,
			trackPrimaryTitle: "A",
			performedAt: Date(timeIntervalSince1970: 100),
			score: 50
		)
		let newer = HistorySessionRowDisplayItem(
			id: idHigh,
			intent: .shout,
			trackPrimaryTitle: "B",
			performedAt: Date(timeIntervalSince1970: 200),
			score: 50
		)
		let out = HistorySortOrder.performedAtDescending.sorted([older, newer])
		XCTAssertEqual(out.map(\.id), [newer.id, older.id])
	}

	/// 概要: .scoreDescending ソートで、スコアが高いセッションが先頭に来ること
	/// 前提(Given): score=50 の新しいセッションと score=90 の古いセッション（スコアが異なる）
	/// 実行(When): HistorySortOrder.scoreDescending.sorted(_:) を呼ぶ
	/// 検証(Then): 返却配列のスコアが [90, 50] の順になる
	func testScoreDescending_PutsHigherScoreFirst() {
		let newerLowScore = HistorySessionRowDisplayItem(
			id: idLow,
			intent: .shout,
			trackPrimaryTitle: "A",
			performedAt: Date(timeIntervalSince1970: 300),
			score: 50
		)
		let olderHighScore = HistorySessionRowDisplayItem(
			id: idHigh,
			intent: .shout,
			trackPrimaryTitle: "B",
			performedAt: Date(timeIntervalSince1970: 100),
			score: 90
		)
		let out = HistorySortOrder.scoreDescending.sorted([newerLowScore, olderHighScore])
		XCTAssertEqual(out.map(\.score), [90, 50])
	}

	/// 概要: .scoreAscending ソートで、スコアが低いセッションが先頭に来ること
	/// 前提(Given): score=99 と score=10 の 2 件
	/// 実行(When): HistorySortOrder.scoreAscending.sorted(_:) を呼ぶ
	/// 検証(Then): 返却配列のスコアが [10, 99] の順になる
	func testScoreAscending_PutsLowerScoreFirst() {
		let high = HistorySessionRowDisplayItem(
			id: idLow,
			intent: .practice,
			trackPrimaryTitle: "A",
			performedAt: Date(timeIntervalSince1970: 100),
			score: 99
		)
		let low = HistorySessionRowDisplayItem(
			id: idHigh,
			intent: .practice,
			trackPrimaryTitle: "B",
			performedAt: Date(timeIntervalSince1970: 200),
			score: 10
		)
		let out = HistorySortOrder.scoreAscending.sorted([high, low])
		XCTAssertEqual(out.map(\.score), [10, 99])
	}

	/// 概要: スコアが等しい場合の第二ソートキーとして performedAt 降順が使われること
	/// 前提(Given): score=80 で performedAt が異なる 2 件（古・新）の .scoreDescending ソート
	/// 実行(When): HistorySortOrder.scoreDescending.sorted(_:) を呼ぶ
	/// 検証(Then): スコアが同値のとき performedAt が新しいセッションが先頭に並ぶ（安定化キー）
	func testEqualScore_UsesPerformedAtDescendingAsSecondary() {
		let older = HistorySessionRowDisplayItem(
			id: idLow,
			intent: .emo,
			trackPrimaryTitle: "A",
			performedAt: Date(timeIntervalSince1970: 100),
			score: 80
		)
		let newer = HistorySessionRowDisplayItem(
			id: idHigh,
			intent: .emo,
			trackPrimaryTitle: "B",
			performedAt: Date(timeIntervalSince1970: 200),
			score: 80
		)
		let out = HistorySortOrder.scoreDescending.sorted([older, newer])
		XCTAssertEqual(out.map(\.performedAt), [newer.performedAt, older.performedAt])
	}
}
