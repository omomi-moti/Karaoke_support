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
