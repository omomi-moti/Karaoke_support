import Foundation
import SwiftData
import Testing

@testable import Karaoke_support

@Suite("SwiftDataSessionRepository の source（どこから付けた記録か）")
@MainActor
struct SwiftDataSessionRepositoryRecordSourceTests {

	private let context: ModelContext
	private let repository: SwiftDataSessionRepository

	init() throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		context = ModelContext(container)
		repository = SwiftDataSessionRepository(modelContext: context)
	}

	private func makeTrack() throws -> Track {
		let track = Track(userEnteredName: "入口テスト曲")
		context.insert(track)
		try context.save()
		return track
	}

	@Test("source を渡さずに作った記録も、空ではなく manual を保存する")
	func defaultsToManual() throws {
		let session = SingingSession(track: try makeTrack(), intent: .shout, score: nil)
		#expect(session.recordedSource == .manual)
	}

	@Test("新しく保存すると、渡した source のまま残る")
	func savesSource() async throws {
		let sessionId = UUID()
		try await repository.saveNewRecordingSession(
			SingingSession(id: sessionId, track: try makeTrack(), intent: .emo, score: 90, source: .suggestion)
		)

		let persisted = try await repository.fetchRecordingSession(uuid: sessionId)
		#expect(persisted.recordedSource == .suggestion)
	}

	@Test("編集で更新しても source は変わらない")
	func updateKeepsSource() async throws {
		let track = try makeTrack()
		let sessionId = UUID()
		try await repository.saveNewRecordingSession(
			SingingSession(id: sessionId, track: track, intent: .emo, score: 90, source: .suggestion)
		)

		// 編集の画面から来る値は source を持たない（初期値の manual）
		try await repository.updateRecordingSession(
			SingingSession(id: sessionId, track: track, intent: .practice, score: 95)
		)

		let persisted = try await repository.fetchRecordingSession(uuid: sessionId)
		#expect(persisted.intent == .practice)
		#expect(persisted.recordedSource == .suggestion)
	}
}
