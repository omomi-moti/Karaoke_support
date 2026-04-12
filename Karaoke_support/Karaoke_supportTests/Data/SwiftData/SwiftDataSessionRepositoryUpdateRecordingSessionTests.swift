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

	/// 概要: 編集保存でフィールドが上書きされ、singCount が増加しないこと
	/// 前提(Given): intent=.shout・score=80・memo="old" で saveNewRecordingSession を呼び、singCount=1 の状態
	/// 実行(When): 同一セッション ID で intent=.emo・score=91.25・memo="new"・performedAt=2_000 に変えた SingingSession で updateRecordingSession を呼ぶ
	/// 検証(Then): Track の singCount は 1 のまま変わらず、DB 上のレコードが新しい intent / score / memo / performedAt に上書きされている
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

	/// 概要: 存在しない ID のセッションを更新しようとすると sessionNotFound エラーがスローされること
	/// 前提(Given): セッションを一切保存していない空のインメモリ DB
	/// 実行(When): 未登録の UUID を持つ SingingSession で updateRecordingSession を呼ぶ
	/// 検証(Then): SessionRepositoryError.sessionNotFound(missingId) がスローされ、エラーに含まれる id が指定した UUID と一致する
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

	/// 概要: 更新時に Track を差し替えようとするとエラーがスローされること（Track の変更は未サポート）
	/// 前提(Given): TrackA に紐づくセッションを saveNewRecordingSession で登録済み
	/// 実行(When): 同一セッション ID で TrackB に紐づけたセッションを updateRecordingSession に渡す
	/// 検証(Then): SessionRepositoryError.sessionUpdateTrackChangeNotSupported がスローされる
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
