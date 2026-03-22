//
//  SwiftDataSessionRepositoryFetchByIntentTests.swift
//  Karaoke_supportTests
//
//  ``SwiftDataSessionRepository/fetchByIntent`` が直近ウィンドウ・Intent 絞り込み・日時降順を満たすことの検証。
//

import SwiftData
import XCTest

@testable import Karaoke_support

final class SwiftDataSessionRepositoryFetchByIntentTests: XCTestCase {

	@MainActor
	func testFetchByIntentReturnsOnlyMatchingIntentInPerformedAtDescendingOrder() async throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		let context = container.mainContext
		let repo = SwiftDataSessionRepository(modelContext: context)

		let track = Track(userEnteredName: "FetchByIntent Order Test")
		context.insert(track)
		try context.save()

		let newest = Date()
		let middle = newest.addingTimeInterval(-100)
		let oldest = newest.addingTimeInterval(-200)

		let shoutNew = SingingSession(track: track, intent: .shout, performedAt: newest, score: 90)
		let emoMid = SingingSession(track: track, intent: .emo, performedAt: middle, score: 85)
		let shoutOld = SingingSession(track: track, intent: .shout, performedAt: oldest, score: 80)
		context.insert(shoutNew)
		context.insert(emoMid)
		context.insert(shoutOld)
		try context.save()

		let shouts = try await repo.fetchByIntent(.shout)
		XCTAssertEqual(shouts.count, 2)
		XCTAssertTrue(shouts.allSatisfy { $0.intent == .shout })
		XCTAssertEqual(shouts[0].performedAt, newest)
		XCTAssertEqual(shouts[1].performedAt, oldest)

		let emos = try await repo.fetchByIntent(.emo)
		XCTAssertEqual(emos.count, 1)
		XCTAssertEqual(emos[0].intent, .emo)
		XCTAssertEqual(emos[0].performedAt, middle)
	}

	/// 直近 ``SessionRecentWindow/maxSessionCount`` 件より古いセッションはウィンドウ外となり、Intent が一致しても返さない。
	@MainActor
	func testFetchByIntentExcludesSessionsOutsideRecentWindow() async throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		let context = container.mainContext
		let repo = SwiftDataSessionRepository(modelContext: context)

		let track = Track(userEnteredName: "FetchByIntent Window Test")
		context.insert(track)
		try context.save()

		let base = Date(timeIntervalSince1970: 1_700_000_000)
		let step: TimeInterval = 60

		// 201 件: 最古のみ Emo、それ以外は Shout。降順で先頭 200 件に Emo は含まれない。
		for i in 0..<(SessionRecentWindow.maxSessionCount + 1) {
			let performedAt = base.addingTimeInterval(step * Double(i))
			let intent: Intent = (i == 0) ? .emo : .shout
			let session = SingingSession(track: track, intent: intent, performedAt: performedAt, score: 70)
			context.insert(session)
		}
		try context.save()

		let emos = try await repo.fetchByIntent(.emo)
		XCTAssertTrue(
			emos.isEmpty,
			"最古の Emo は直近 \(SessionRecentWindow.maxSessionCount) 件の外に落ちるため空になる"
		)

		let shouts = try await repo.fetchByIntent(.shout)
		XCTAssertEqual(shouts.count, SessionRecentWindow.maxSessionCount)
		XCTAssertTrue(shouts.allSatisfy { $0.intent == .shout })

		for pair in zip(shouts, shouts.dropFirst()) {
			XCTAssertGreaterThanOrEqual(pair.0.performedAt, pair.1.performedAt, "performedAt 降順")
		}

		let newestShoutTime = base.addingTimeInterval(step * Double(SessionRecentWindow.maxSessionCount))
		XCTAssertEqual(shouts[0].performedAt, newestShoutTime)
	}
}
