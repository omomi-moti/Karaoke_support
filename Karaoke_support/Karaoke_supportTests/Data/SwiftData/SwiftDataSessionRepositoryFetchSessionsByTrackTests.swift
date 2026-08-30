import Foundation
import SwiftData
import Testing

@testable import Karaoke_support

@Suite("SwiftDataSessionRepository.fetchSessions(trackId:)")
@MainActor
struct SwiftDataSessionRepositoryFetchSessionsByTrackTests {

	private let context: ModelContext
	private let repository: SwiftDataSessionRepository

	init() throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		context = ModelContext(container)
		repository = SwiftDataSessionRepository(modelContext: context)
	}

	private func makeTrack(named name: String) throws -> Track {
		let track = Track(userEnteredName: name)
		context.insert(track)
		try context.save()
		return track
	}

	@Test("performedAt 昇順で返る（保存順に依存しない）")
	func returnsSessionsInAscendingPerformedAtOrder() async throws {
		let track = try makeTrack(named: "推移テスト曲")

		for interval in [300.0, 100.0, 200.0] {
			try await repository.saveNewRecordingSession(
				SingingSession(
					track: track,
					intent: .shout,
					performedAt: Date(timeIntervalSince1970: interval),
					score: 80
				)
			)
		}

		let sessions = try await repository.fetchSessions(trackId: track.id)
		#expect(sessions.map(\.performedAt.timeIntervalSince1970) == [100, 200, 300])
	}

	@Test("他 Track のセッションを含まない")
	func excludesSessionsOfOtherTracks() async throws {
		let trackA = try makeTrack(named: "A")
		let trackB = try makeTrack(named: "B")

		try await repository.saveNewRecordingSession(SingingSession(track: trackA, intent: .shout, score: 70))
		try await repository.saveNewRecordingSession(SingingSession(track: trackA, intent: .emo, score: 75))
		try await repository.saveNewRecordingSession(SingingSession(track: trackB, intent: .practice, score: 90))

		let sessions = try await repository.fetchSessions(trackId: trackA.id)
		#expect(sessions.count == 2)
		#expect(sessions.allSatisfy { session in session.track.id == trackA.id })
	}

	@Test("未登録の trackId では空配列を返す")
	func returnsEmptyForUnknownTrackId() async throws {
		let sessions = try await repository.fetchSessions(trackId: UUID())
		#expect(sessions.isEmpty)
	}

	@Test("削除したセッションは返らない")
	func reflectsDeletedSession() async throws {
		let track = try makeTrack(named: "削除テスト曲")

		let keptId = UUID()
		let removedId = UUID()
		try await repository.saveNewRecordingSession(
			SingingSession(
				id: keptId,
				track: track,
				intent: .shout,
				performedAt: Date(timeIntervalSince1970: 100),
				score: 80
			)
		)
		try await repository.saveNewRecordingSession(
			SingingSession(
				id: removedId,
				track: track,
				intent: .emo,
				performedAt: Date(timeIntervalSince1970: 200),
				score: 85
			)
		)

		try await repository.deleteRecordingSession(uuid: removedId)

		let sessions = try await repository.fetchSessions(trackId: track.id)
		#expect(sessions.map(\.id) == [keptId])
	}
}
