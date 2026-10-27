import Foundation
import SwiftData
import Testing

@testable import Karaoke_support

@Suite("SwiftDataSessionRepository の isCompleted（歌い切れたか）")
@MainActor
struct SwiftDataSessionRepositoryCompletionTests {

	private let context: ModelContext
	private let repository: SwiftDataSessionRepository

	init() throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		context = ModelContext(container)
		repository = SwiftDataSessionRepository(modelContext: context)
	}

	private func makeTrack() throws -> Track {
		let track = Track(userEnteredName: "歌い切れたかテスト曲")
		context.insert(track)
		try context.save()
		return track
	}

	@Test("isCompleted を渡さずに作った記録も、空ではなく true を保存する")
	func defaultsToTrue() throws {
		let session = SingingSession(track: try makeTrack(), intent: .shout, score: nil)
		#expect(session.recordedIsCompleted == true)
	}

	@Test("新しく保存すると、渡した isCompleted のまま残る")
	func savesIsCompleted() async throws {
		let sessionId = UUID()
		try await repository.saveNewRecordingSession(
			SingingSession(id: sessionId, track: try makeTrack(), intent: .emo, score: nil, isCompleted: false)
		)

		let persisted = try await repository.fetchRecordingSession(uuid: sessionId)
		#expect(persisted.recordedIsCompleted == false)
	}

	@Test("編集で更新すると、歌い切れなかったに変えられる")
	func updateToNotCompleted() async throws {
		let track = try makeTrack()
		let sessionId = UUID()
		try await repository.saveNewRecordingSession(SingingSession(id: sessionId, track: track, intent: .emo, score: 90))

		try await repository.updateRecordingSession(
			SingingSession(id: sessionId, track: track, intent: .emo, score: 90, isCompleted: false)
		)

		let persisted = try await repository.fetchRecordingSession(uuid: sessionId)
		#expect(persisted.isCompleted == false)
	}

	@Test("編集で更新すると、歌い切れたに戻せる")
	func updateToCompleted() async throws {
		let track = try makeTrack()
		let sessionId = UUID()
		try await repository.saveNewRecordingSession(
			SingingSession(id: sessionId, track: track, intent: .emo, score: nil, isCompleted: false)
		)

		try await repository.updateRecordingSession(
			SingingSession(id: sessionId, track: track, intent: .emo, score: 90, isCompleted: true)
		)

		let persisted = try await repository.fetchRecordingSession(uuid: sessionId)
		#expect(persisted.isCompleted)
	}
}
