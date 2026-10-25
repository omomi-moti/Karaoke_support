import Foundation
import Testing

@testable import Karaoke_support

@MainActor
private final class FixedTrackRepository: TrackRepositoryProtocol {
	let track = Track(userEnteredName: "曲")

	func searchLocal(query: String) async throws -> [Track] { [] }

	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?) async throws -> Track { track }

	func incrementSingCount(trackId: UUID) async throws {}
}

/// 新しく保存した記録を覚えておく。
@MainActor
private final class CapturingSessionRepository: SessionRepositoryProtocol {
	private(set) var savedSessions: [SingingSession] = []

	func saveNewRecordingSession(_ session: SingingSession) async throws {
		savedSessions.append(session)
	}

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

@Suite("RecordingSheetViewModel.save() で決める入口（source）")
@MainActor
struct RecordingSheetViewModelRecordSourceTests {

	private let sessionRepository = CapturingSessionRepository()

	private func makeViewModel(_ selected: SelectedTrack, source: RecordSource) -> RecordingSheetViewModel {
		RecordingSheetViewModel(
			selectedTrack: selected,
			intent: .emo,
			source: source,
			sessionRepository: sessionRepository,
			trackRepository: FixedTrackRepository()
		)
	}

	@Test("提案のカードから開いて、曲を変えずに保存すると suggestion")
	func suggestionWhenTrackUnchanged() async throws {
		let selected = try #require(SelectedTrack(spotifyTrackId: nil, userEnteredName: "涙そうそう"))
		let vm = makeViewModel(selected, source: .suggestion)

		#expect(await vm.save() != nil)
		#expect(sessionRepository.savedSessions.map(\.recordedSource) == [.suggestion])
	}

	@Test("Spotify の曲でも、曲を変えずに保存すると suggestion")
	func suggestionForSpotifyTrack() async throws {
		let selected = try #require(SelectedTrack(spotifyTrackId: "spotify-id", userEnteredName: "Lemon"))
		let vm = makeViewModel(selected, source: .suggestion)

		#expect(await vm.save() != nil)
		#expect(sessionRepository.savedSessions.map(\.recordedSource) == [.suggestion])
	}

	@Test("気分だけ変えて保存しても suggestion のまま")
	func suggestionWhenOnlyIntentChanged() async throws {
		let selected = try #require(SelectedTrack(spotifyTrackId: nil, userEnteredName: "涙そうそう"))
		let vm = makeViewModel(selected, source: .suggestion)
		vm.draft.intent = .practice

		#expect(await vm.save() != nil)
		#expect(sessionRepository.savedSessions.map(\.recordedSource) == [.suggestion])
	}

	@Test("提案のカードから開いても、曲名を書き換えて保存すると manual")
	func manualWhenTrackNameEdited() async throws {
		let selected = try #require(SelectedTrack(spotifyTrackId: nil, userEnteredName: "涙そうそう"))
		let vm = makeViewModel(selected, source: .suggestion)
		vm.trackState.manualName = "島唄"

		#expect(await vm.save() != nil)
		#expect(sessionRepository.savedSessions.map(\.recordedSource) == [.manual])
	}

	@Test("曲名の前後に空白を足しただけなら、書き換えたことにしない")
	func suggestionWhenOnlyWhitespaceAdded() async throws {
		let selected = try #require(SelectedTrack(spotifyTrackId: nil, userEnteredName: "涙そうそう"))
		let vm = makeViewModel(selected, source: .suggestion)
		vm.trackState.manualName = " 涙そうそう "

		#expect(await vm.save() != nil)
		#expect(sessionRepository.savedSessions.map(\.recordedSource) == [.suggestion])
	}

	@Test("ランキングや検索など、提案以外から曲を入れて開くと manual")
	func manualWhenOpenedFromElsewhere() async throws {
		let selected = try #require(SelectedTrack(spotifyTrackId: nil, userEnteredName: "涙そうそう"))
		let vm = makeViewModel(selected, source: .manual)

		#expect(await vm.save() != nil)
		#expect(sessionRepository.savedSessions.map(\.recordedSource) == [.manual])
	}

	@Test("＋から開いて保存すると manual")
	func manualWhenOpenedFromAddButton() async throws {
		let vm = RecordingSheetViewModel(
			trackMode: .manual,
			sessionRepository: sessionRepository,
			trackRepository: FixedTrackRepository()
		)
		vm.trackState.manualName = "涙そうそう"

		#expect(await vm.save() != nil)
		#expect(sessionRepository.savedSessions.map(\.recordedSource) == [.manual])
	}
}
