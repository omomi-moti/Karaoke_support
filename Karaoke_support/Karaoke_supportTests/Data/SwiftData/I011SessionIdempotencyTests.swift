//
//  I011SessionIdempotencyTests.swift
//  Karaoke_supportTests
//
//  I-011: 同一 SingingSession.id で saveNewRecordingSession を複数回呼んでも二重登録しないことの検証。
//

import SwiftData
import XCTest

@testable import Karaoke_support

final class I011SessionIdempotencyTests: XCTestCase {

	/// 概要: 同一 UUID で saveNewRecordingSession を 2 回呼んでも、DB 行の重複登録と singCount の二重加算が起きないこと（冪等性の保証）
	/// 前提(Given): 同一 UUID・同一内容の SingingSession を用意し、1 回目の saveNewRecordingSession 後に singCount=1・行数=1 を確認
	/// 実行(When): 同じ UUID で 2 回目の saveNewRecordingSession を呼ぶ
	/// 検証(Then): singCount が 1 のまま増えず、DB 上の SingingSession 行数も 1 件のまま変わらない
	@MainActor
	func testSaveNewRecordingSessionSecondCallWithSameIdDoesNotDoubleIncrement() async throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		let context = container.mainContext
		let repo = SwiftDataSessionRepository(modelContext: context)

		let track = Track(userEnteredName: "I-011 Test Track")
		context.insert(track)
		try context.save()

		let id = UUID()
		let first = SingingSession(id: id, track: track, intent: .shout, score: 80)
		try await repo.saveNewRecordingSession(first)

		XCTAssertEqual(track.singCount, 1)
		let afterFirst = try context.fetch(FetchDescriptor<SingingSession>()).count
		XCTAssertEqual(afterFirst, 1)

		let second = SingingSession(id: id, track: track, intent: .shout, score: 80)
		try await repo.saveNewRecordingSession(second)

		XCTAssertEqual(track.singCount, 1, "冪等: singCount は増えない")
		let afterSecond = try context.fetch(FetchDescriptor<SingingSession>()).count
		XCTAssertEqual(afterSecond, 1, "冪等: セッション行は 1 件のまま")
	}
}
