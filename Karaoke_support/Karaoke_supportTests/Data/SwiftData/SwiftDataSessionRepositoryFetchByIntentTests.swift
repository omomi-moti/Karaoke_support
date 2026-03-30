//
//  SwiftDataSessionRepositoryFetchByIntentTests.swift
//  Karaoke_supportTests
//
//  ``SwiftDataSessionRepository/fetchByIntent(_:limit:offset:)`` がページング・Intent 絞り込み・日時降順を満たすことの検証。
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

		let shouts = try await repo.fetchByIntent(.shout, limit: 20, offset: 0)
		XCTAssertEqual(shouts.count, 2)
		XCTAssertTrue(shouts.allSatisfy { $0.intent == .shout })
		XCTAssertEqual(shouts[0].performedAt, newest)
		XCTAssertEqual(shouts[1].performedAt, oldest)

		let emos = try await repo.fetchByIntent(.emo, limit: 20, offset: 0)
		XCTAssertEqual(emos.count, 1)
		XCTAssertEqual(emos[0].intent, .emo)
		XCTAssertEqual(emos[0].performedAt, middle)
	}

	/// limit / offset のページングが Intent 絞り込み後の配列に対して適用されることを検証する。
	@MainActor
	func testFetchByIntentSupportsPaging() async throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		let context = container.mainContext
		let repo = SwiftDataSessionRepository(modelContext: context)

		let track = Track(userEnteredName: "FetchByIntent Window Test")
		context.insert(track)
		try context.save()

		let base = Date(timeIntervalSince1970: 1_710_000_000)
		let step: TimeInterval = 60

		// 60 件: 偶数 index を Emo、奇数 index を Shout とする。
		for i in 0..<60 {
			let performedAt = base.addingTimeInterval(step * Double(i))
			let intent: Intent = (i % 2 == 0) ? .emo : .shout
			let session = SingingSession(track: track, intent: intent, performedAt: performedAt, score: 70)
			context.insert(session)
		}
		try context.save()

		let firstPage = try await repo.fetchByIntent(.emo, limit: 10, offset: 0)
		let secondPage = try await repo.fetchByIntent(.emo, limit: 10, offset: 10)
		let thirdPage = try await repo.fetchByIntent(.emo, limit: 10, offset: 20)
		let outOfRange = try await repo.fetchByIntent(.emo, limit: 10, offset: 30)

		XCTAssertEqual(firstPage.count, 10)
		XCTAssertEqual(secondPage.count, 10)
		XCTAssertEqual(thirdPage.count, 10)
		XCTAssertTrue(outOfRange.isEmpty)
		XCTAssertTrue((firstPage + secondPage + thirdPage).allSatisfy { $0.intent == .emo })

		for pair in zip(firstPage, firstPage.dropFirst()) {
			XCTAssertGreaterThanOrEqual(pair.0.performedAt, pair.1.performedAt, "performedAt 降順")
		}

		XCTAssertGreaterThan(firstPage[0].performedAt, secondPage[0].performedAt)
		XCTAssertGreaterThan(secondPage[0].performedAt, thirdPage[0].performedAt)
	}
}
