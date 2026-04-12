//
//  SwiftDataSessionRepositoryFetchRecordingSessionTests.swift
//  Karaoke_supportTests
//
//  ``SwiftDataSessionRepository/fetchRecordingSession(uuid:)`` の契約検証。
//

import SwiftData
import XCTest

@testable import Karaoke_support

final class SwiftDataSessionRepositoryFetchRecordingSessionTests: XCTestCase {

	/// 概要: 保存済みセッションを UUID で取得したとき、全フィールドが保存時と一致すること
	/// 前提(Given): UUID・intent=.practice・score=77.5・memo="fetch me"・performedAt 指定のセッションを saveNewRecordingSession で保存
	/// 実行(When): 保存時と同一の UUID で fetchRecordingSession(uuid:) を呼ぶ
	/// 検証(Then): 返却されたセッションの id / intent / score / memo / performedAt / track.id がすべて保存値と一致する
	@MainActor
	func testFetchRecordingSessionReturnsPersistedSession() async throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		let context = container.mainContext
		let repo = SwiftDataSessionRepository(modelContext: context)

		let track = Track(userEnteredName: "Fetch Test Track")
		context.insert(track)
		try context.save()

		let sessionId = UUID()
		let performedAt = Date(timeIntervalSince1970: 3_000)
		let original = SingingSession(
			id: sessionId,
			track: track,
			intent: .practice,
			performedAt: performedAt,
			score: 77.5,
			memo: "fetch me"
		)
		try await repo.saveNewRecordingSession(original)

		let fetched = try await repo.fetchRecordingSession(uuid: sessionId)
		XCTAssertEqual(fetched.id, sessionId)
		XCTAssertEqual(fetched.intent, .practice)
		XCTAssertEqual(fetched.score, 77.5)
		XCTAssertEqual(fetched.memo, "fetch me")
		XCTAssertEqual(fetched.performedAt, performedAt)
		XCTAssertEqual(fetched.track.id, track.id)
	}

	/// 概要: 存在しない UUID を指定した場合に sessionNotFound エラーがスローされること
	/// 前提(Given): セッションを一切保存していない空のインメモリ DB
	/// 実行(When): 未登録の UUID で fetchRecordingSession(uuid:) を呼ぶ
	/// 検証(Then): SessionRepositoryError.sessionNotFound(missingId) がスローされ、エラーに含まれる id が指定した UUID と一致する
	@MainActor
	func testFetchRecordingSessionThrowsWhenIdMissing() async throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		let context = container.mainContext
		let repo = SwiftDataSessionRepository(modelContext: context)

		let missingId = UUID()
		do {
			_ = try await repo.fetchRecordingSession(uuid: missingId)
			XCTFail("存在しない id では sessionNotFound")
		} catch SessionRepositoryError.sessionNotFound(let id) {
			XCTAssertEqual(id, missingId)
		}
	}
}
