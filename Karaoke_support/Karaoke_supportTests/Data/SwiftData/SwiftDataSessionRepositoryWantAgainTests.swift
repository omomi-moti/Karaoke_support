import Foundation
import SwiftData
import Testing

@testable import Karaoke_support

@Suite("SwiftDataSessionRepository の wantAgain（ハート）")
@MainActor
struct SwiftDataSessionRepositoryWantAgainTests {

	private let context: ModelContext
	private let repository: SwiftDataSessionRepository

	init() throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		context = ModelContext(container)
		repository = SwiftDataSessionRepository(modelContext: context)
	}

	private func makeTrack() throws -> Track {
		let track = Track(userEnteredName: "ハートテスト曲")
		context.insert(track)
		try context.save()
		return track
	}

	@Test("wantAgain を渡さずに作った記録も、空ではなく false を保存する")
	func defaultsToFalse() throws {
		let session = SingingSession(track: try makeTrack(), intent: .shout, score: nil)
		#expect(session.recordedWantAgain == false)
	}

	@Test("新しく保存すると、渡した wantAgain のまま残る")
	func savesWantAgain() async throws {
		let sessionId = UUID()
		try await repository.saveNewRecordingSession(
			SingingSession(id: sessionId, track: try makeTrack(), intent: .emo, score: 90, wantAgain: true)
		)

		let persisted = try await repository.fetchRecordingSession(uuid: sessionId)
		#expect(persisted.recordedWantAgain == true)
	}

	@Test("編集で更新すると、ハートを付けられる")
	func updateTurnsOn() async throws {
		let track = try makeTrack()
		let sessionId = UUID()
		try await repository.saveNewRecordingSession(SingingSession(id: sessionId, track: track, intent: .emo, score: 90))

		try await repository.updateRecordingSession(
			SingingSession(id: sessionId, track: track, intent: .emo, score: 90, wantAgain: true)
		)

		let persisted = try await repository.fetchRecordingSession(uuid: sessionId)
		#expect(persisted.wantAgain)
	}

	@Test("編集で更新すると、ハートを外せる")
	func updateTurnsOff() async throws {
		let track = try makeTrack()
		let sessionId = UUID()
		try await repository.saveNewRecordingSession(
			SingingSession(id: sessionId, track: track, intent: .emo, score: 90, wantAgain: true)
		)

		try await repository.updateRecordingSession(
			SingingSession(id: sessionId, track: track, intent: .emo, score: 90, wantAgain: false)
		)

		let persisted = try await repository.fetchRecordingSession(uuid: sessionId)
		#expect(persisted.wantAgain == false)
	}
}
