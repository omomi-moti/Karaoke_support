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

	/// 概要: Intent で絞り込んだ結果が他の Intent を含まず、performedAt 降順で返ること
	/// 前提(Given): インメモリ DB に同一 Track の .shout セッション 2 件（最新・最旧）と .emo セッション 1 件（中間）を保存
	/// 実行(When): fetchByIntent(.shout, limit:20, offset:0) と fetchByIntent(.emo, limit:20, offset:0) をそれぞれ呼ぶ
	/// 検証(Then): .shout は 2 件ですべて .shout かつ新しい順に並び、.emo は 1 件で .emo のみ返る
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

	/// 概要: limit / offset のページングが Intent 絞り込み後の結果に正しく適用されること
	/// 前提(Given): 60 件のセッション（偶数 index = .emo, 奇数 index = .shout）をインメモリ DB に保存
	/// 実行(When): .emo を limit=10 で offset=0, 10, 20, 30 と順次 fetchByIntent を呼ぶ
	/// 検証(Then): 先頭 3 ページは 10 件ずつ全件 .emo で performedAt 降順、offset=30 は空配列となり、ページ間で performedAt が連続的に降順になること
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
