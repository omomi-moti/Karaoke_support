//
//  SwiftDataSessionRepositoryUpdateRecordingSessionTests.swift
//  Karaoke_supportTests
//
//  ``SwiftDataSessionRepository/updateRecordingSession`` の契約検証（I-011 新規との分離）。
//

import SwiftData
import XCTest

@testable import Karaoke_support

final class SwiftDataSessionRepositoryUpdateRecordingSessionTests: XCTestCase {

	@MainActor
	func testUpdateRecordingSessionOverwritesFieldsWithoutIncrementingSingCount() async throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		let context = container.mainContext
		let repo = SwiftDataSessionRepository(modelContext: context)

		let track = Track(userEnteredName: "Update Test Track")
		context.insert(track)
		try context.save()

		let sessionId = UUID()
		let original = SingingSession(
			id: sessionId,
			track: track,
			intent: .shout,
			performedAt: Date(timeIntervalSince1970: 1_000),
			score: 80,
			memo: "old"
		)
		try await repo.saveNewRecordingSession(original)
		XCTAssertEqual(track.singCount, 1)

		let edited = SingingSession(
			id: sessionId,
			track: track,
			intent: .emo,
			performedAt: Date(timeIntervalSince1970: 2_000),
			score: 91.25,
			memo: "new"
		)
		try await repo.updateRecordingSession(edited)
		XCTAssertEqual(track.singCount, 1, "編集では singCount を増やさない")

		let idToMatch = sessionId
		var fetchDescriptor = FetchDescriptor<SingingSession>(
			predicate: #Predicate<SingingSession> { $0.id == idToMatch }
		)
		fetchDescriptor.fetchLimit = 1
		let persisted = try context.fetch(fetchDescriptor).first
		XCTAssertEqual(persisted?.intent, .emo)
		XCTAssertEqual(persisted?.score, 91.25)
		XCTAssertEqual(persisted?.memo, "new")
		XCTAssertEqual(persisted?.performedAt, Date(timeIntervalSince1970: 2_000))
	}

	@MainActor
	func testUpdateRecordingSessionThrowsWhenIdMissing() async throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		let context = container.mainContext
		let repo = SwiftDataSessionRepository(modelContext: context)

		let track = Track(userEnteredName: "Missing Id Track")
		context.insert(track)
		try context.save()

		let missingId = UUID()
		let proposal = SingingSession(id: missingId, track: track, intent: .practice, score: 50)

		do {
			try await repo.updateRecordingSession(proposal)
			XCTFail("存在しない id では sessionNotFound を投げる")
		} catch SessionRepositoryError.sessionNotFound(let id) {
			XCTAssertEqual(id, missingId)
		}
	}

	@MainActor
	func testUpdateRecordingSessionThrowsWhenTrackChanges() async throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		let context = container.mainContext
		let repo = SwiftDataSessionRepository(modelContext: context)

		let trackA = Track(userEnteredName: "Track A")
		let trackB = Track(userEnteredName: "Track B")
		context.insert(trackA)
		context.insert(trackB)
		try context.save()

		let sessionId = UUID()
		let original = SingingSession(id: sessionId, track: trackA, intent: .shout, score: 70)
		try await repo.saveNewRecordingSession(original)

		let proposal = SingingSession(id: sessionId, track: trackB, intent: .emo, score: 71)

		do {
			try await repo.updateRecordingSession(proposal)
			XCTFail("Track 差し替えは未対応")
		} catch SessionRepositoryError.sessionUpdateTrackChangeNotSupported {
			// ok
		}
	}
}
