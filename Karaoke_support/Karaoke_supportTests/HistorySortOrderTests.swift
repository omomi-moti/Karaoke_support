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
