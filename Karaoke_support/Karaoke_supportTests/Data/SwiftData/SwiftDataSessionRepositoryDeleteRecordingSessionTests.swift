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
	/// 保存済みのセッションを削除した場合、データ行が削除され、紐づくTrackのsingCountが1減少すること
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
    /// 存在しないセッションIDを指定して削除を試みた場合、sessionNotFoundエラーとなること
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
