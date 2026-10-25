import Foundation
import Testing

@testable import Karaoke_support

@MainActor
private final class UnusedTrackRepository: TrackRepositoryProtocol {
	func searchLocal(query: String) async throws -> [Track] { [] }

	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?) async throws -> Track {
		Track(userEnteredName: userEnteredName ?? "曲")
	}

	func incrementSingCount(trackId: UUID) async throws {}
}

@MainActor
private final class UnusedSessionRepository: SessionRepositoryProtocol {
	func saveNewRecordingSession(_ session: SingingSession) async throws {}

	func updateRecordingSession(_ session: SingingSession) async throws {}

	func deleteRecordingSession(uuid: UUID) async throws {}

	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession] { [] }

	func fetchByIntent(_ intent: Intent, limit: Int, offset: Int) async throws -> [SingingSession] { [] }

	func exists(uuid: UUID) async throws -> Bool { false }

	func fetchRecordingSession(uuid: UUID) async throws -> SingingSession {
		throw SessionRepositoryError.sessionNotFound(uuid)
	}

	func fetchSessions(trackId: UUID) async throws -> [SingingSession] { [] }
}

@Suite("RecordingSheetViewModel 曲と気分を入れて開く")
@MainActor
struct RecordingSheetViewModelSelectedTrackIntentTests {

	@Test("曲と気分を渡して開くと、その気分を選んだ状態になる")
	func opensWithGivenIntent() throws {
		let selected = try #require(SelectedTrack(spotifyTrackId: nil, userEnteredName: "涙そうそう"))
		let vm = RecordingSheetViewModel(
			selectedTrack: selected,
			intent: .emo,
			sessionRepository: UnusedSessionRepository(),
			trackRepository: UnusedTrackRepository()
		)
		#expect(vm.draft.intent == .emo)
		#expect(vm.trackState.manualName == "涙そうそう")
	}

	@Test("気分を渡さずに開くと、今までどおり Shout になる")
	func opensWithDefaultIntentWhenNotGiven() throws {
		let selected = try #require(SelectedTrack(spotifyTrackId: nil, userEnteredName: "涙そうそう"))
		let vm = RecordingSheetViewModel(
			selectedTrack: selected,
			sessionRepository: UnusedSessionRepository(),
			trackRepository: UnusedTrackRepository()
		)
		#expect(vm.draft.intent == .shout)
	}
}
