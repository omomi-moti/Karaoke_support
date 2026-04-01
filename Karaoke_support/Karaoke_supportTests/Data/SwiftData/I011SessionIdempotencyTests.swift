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
    /// "境界：同一クライアント生成 UUID で saveNewRecordingSession を二度呼んでも、セッション行は1件のまま・singCount も二重に増えない"
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
