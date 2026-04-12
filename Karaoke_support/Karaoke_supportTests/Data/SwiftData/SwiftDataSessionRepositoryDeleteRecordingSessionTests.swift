//
//  SwiftDataSessionRepositoryDeleteRecordingSessionTests.swift
//  Karaoke_supportTests
//
//  ``SwiftDataSessionRepository/deleteRecordingSession`` と `singCount` 整合の検証。
//

import SwiftData
import XCTest

@testable import Karaoke_support

final class SwiftDataSessionRepositoryDeleteRecordingSessionTests: XCTestCase {

	/// 概要: 保存済みのセッションを削除すると、DB 行が消え、紐づく Track の singCount が 1 減少すること
	/// 前提(Given): saveNewRecordingSession で保存し singCount=1 になっているセッション
	/// 実行(When): そのセッションの UUID で deleteRecordingSession(uuid:) を呼ぶ
	/// 検証(Then): Track の singCount が 0 になり、該当 UUID の SingingSession が DB から存在しなくなる
	@MainActor
	func testDeleteRecordingSessionRemovesRowAndDecrementsSingCount() async throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		let context = container.mainContext
		let repo = SwiftDataSessionRepository(modelContext: context)

		let track = Track(userEnteredName: "Delete Test Track")
		context.insert(track)
		try context.save()

		let sessionId = UUID()
		let session = SingingSession(id: sessionId, track: track, intent: .shout, score: 80)
		try await repo.saveNewRecordingSession(session)
		XCTAssertEqual(track.singCount, 1)

		try await repo.deleteRecordingSession(uuid: sessionId)

		XCTAssertEqual(track.singCount, 0)
		let idToMatch = sessionId
		var fetchDescriptor = FetchDescriptor<SingingSession>(
			predicate: #Predicate<SingingSession> { $0.id == idToMatch }
		)
		fetchDescriptor.fetchLimit = 1
		let remaining = try context.fetch(fetchDescriptor)
		XCTAssertTrue(remaining.isEmpty)
	}

	/// 概要: 存在しない UUID で削除を試みると sessionNotFound エラーがスローされること
	/// 前提(Given): セッションを一切保存していない空のインメモリ DB
	/// 実行(When): 未登録の UUID で deleteRecordingSession(uuid:) を呼ぶ
	/// 検証(Then): SessionRepositoryError.sessionNotFound(missingId) がスローされ、エラーに含まれる id が指定した UUID と一致する
	@MainActor
	func testDeleteRecordingSessionThrowsWhenIdMissing() async throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		let context = container.mainContext
		let repo = SwiftDataSessionRepository(modelContext: context)

		let missingId = UUID()
		do {
			try await repo.deleteRecordingSession(uuid: missingId)
			XCTFail("存在しない id では sessionNotFound")
		} catch SessionRepositoryError.sessionNotFound(let id) {
			XCTAssertEqual(id, missingId)
		}
	}
}
