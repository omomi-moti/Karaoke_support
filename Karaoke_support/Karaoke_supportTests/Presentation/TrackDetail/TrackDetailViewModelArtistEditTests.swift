import Foundation
import Testing

@testable import Karaoke_support

@MainActor
private final class EmptySessionRepository: SessionRepositoryProtocol {
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

private struct StubError: Error {}

@MainActor
private final class ArtistEditTrackRepositoryStub: TrackRepositoryProtocol {
	var updateResult: (String, UUID) -> ArtistNameUpdateResult = { artist, id in
		.updated(Track(id: id, userEnteredName: "Lemon", userEnteredArtistName: artist))
	}
	var updateError: Error?
	var mergeError: Error?
	private(set) var updatedArtists: [(String, UUID)] = []
	private(set) var merges: [(UUID, UUID)] = []

	func searchLocal(query: String) async throws -> [Track] { [] }
	func searchLocalByArtist(query: String) async throws -> [Track] { [] }
	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?, userEnteredArtistName: String?) async throws -> Track {
		Track(userEnteredName: "曲")
	}
	func fillArtistName(_ artistName: String, trackId: UUID) async throws -> Track {
		Track(id: trackId, userEnteredName: "曲", userEnteredArtistName: artistName)
	}
	func updateArtistName(_ artistName: String, trackId: UUID) async throws -> ArtistNameUpdateResult {
		updatedArtists.append((artistName, trackId))
		if let updateError { throw updateError }
		return updateResult(artistName, trackId)
	}
	func mergeTrack(_ sourceId: UUID, into targetId: UUID) async throws -> Track {
		merges.append((sourceId, targetId))
		if let mergeError { throw mergeError }
		return Track(id: targetId, userEnteredName: "Lemon", userEnteredArtistName: "米津玄師")
	}
	func incrementSingCount(trackId: UUID) async throws {}
}

@Suite("TrackDetailViewModel の歌手名を直す")
@MainActor
struct TrackDetailViewModelArtistEditTests {

	private let trackId = UUID()
	private let repository = ArtistEditTrackRepositoryStub()

	private func makeViewModel(artistName: String?) -> TrackDetailViewModel {
		TrackDetailViewModel(
			sessionRepository: EmptySessionRepository(),
			trackRepository: repository,
			trackId: trackId,
			trackTitle: "Lemon",
			trackArtistName: artistName
		)
	}

	@Test("直す欄は今の歌手名で始まる。歌手名のない曲は空")
	func beginArtistEdit_prefillsCurrentArtist() {
		let vm = makeViewModel(artistName: "米津元師")
		vm.beginArtistEdit()
		#expect(vm.artistNameDraft == "米津元師")

		let artistless = makeViewModel(artistName: nil)
		artistless.beginArtistEdit()
		#expect(artistless.artistNameDraft == "")
	}

	@Test("空白だけの歌手名は保存できない")
	func blankDraft_cannotSave() async {
		let vm = makeViewModel(artistName: "米津元師")
		vm.artistNameDraft = "  　"

		#expect(vm.canSaveArtistName == false)
		#expect(await vm.saveArtistName() == false)
		#expect(repository.updatedArtists.isEmpty)
	}

	@Test("前後の空白を落として保存し、表示中の歌手名を変える")
	func save_trimsAndUpdates() async {
		let vm = makeViewModel(artistName: "米津元師")
		vm.artistNameDraft = " 米津玄師 "

		let changed = await vm.saveArtistName()

		#expect(changed)
		#expect(repository.updatedArtists.map(\.0) == ["米津玄師"])
		#expect(repository.updatedArtists.map(\.1) == [trackId])
		#expect(vm.trackArtistName == "米津玄師")
		#expect(vm.trackId == trackId)
		#expect(vm.pendingMerge == nil)
	}

	@Test("今と同じ歌手名なら、変わっていないと返す")
	func save_unchanged_returnsFalse() async {
		let vm = makeViewModel(artistName: "米津玄師")
		vm.artistNameDraft = "米津玄師"

		#expect(await vm.saveArtistName() == false)
		#expect(vm.artistEditErrorMessage == nil)
	}

	@Test("別の曲と重なったら、書かずにまとめる前の確認を出す")
	func save_conflict_setsPendingMerge() async {
		let other = Track(userEnteredName: "Lemon", userEnteredArtistName: "米津玄師", singCount: 4)
		repository.updateResult = { _, _ in .conflicts(with: other) }
		let vm = makeViewModel(artistName: "米津元師")
		vm.artistNameDraft = "米津玄師"

		let changed = await vm.saveArtistName()

		#expect(changed == false)
		#expect(vm.pendingMerge == TrackMergeCandidate(trackId: other.id, artistName: "米津玄師", singCount: 4))
		#expect(vm.trackArtistName == "米津元師")
	}

	@Test("保存に失敗したら、歌手名を変えずにエラーを出す")
	func save_failure_showsError() async {
		repository.updateError = StubError()
		let vm = makeViewModel(artistName: "米津元師")
		vm.artistNameDraft = "米津玄師"

		#expect(await vm.saveArtistName() == false)
		#expect(vm.trackArtistName == "米津元師")
		#expect(vm.artistEditErrorMessage != nil)
	}

	@Test("まとめると、まとめた先の曲に変わる")
	func merge_switchesToTarget() async {
		let vm = makeViewModel(artistName: "米津元師")
		let targetId = UUID()
		let candidate = TrackMergeCandidate(trackId: targetId, artistName: "米津玄師", singCount: 4)

		let merged = await vm.merge(into: candidate)

		#expect(merged)
		#expect(repository.merges.map(\.0) == [trackId])
		#expect(repository.merges.map(\.1) == [targetId])
		#expect(vm.trackId == targetId)
		#expect(vm.trackArtistName == "米津玄師")
		#expect(vm.pendingMerge == nil)
	}

	@Test("まとめるのに失敗したら、曲を変えずにエラーを出す")
	func merge_failure_keepsTrack() async {
		repository.mergeError = StubError()
		let vm = makeViewModel(artistName: "米津元師")
		let candidate = TrackMergeCandidate(trackId: UUID(), artistName: "米津玄師", singCount: 4)

		#expect(await vm.merge(into: candidate) == false)
		#expect(vm.trackId == trackId)
		#expect(vm.trackArtistName == "米津元師")
		#expect(vm.artistEditErrorMessage != nil)
	}

	@Test("確認を閉じると、まとめる前の確認は消える")
	func cancelMerge_clearsPending() async {
		let other = Track(userEnteredName: "Lemon", userEnteredArtistName: "米津玄師")
		repository.updateResult = { _, _ in .conflicts(with: other) }
		let vm = makeViewModel(artistName: "米津元師")
		vm.artistNameDraft = "米津玄師"
		_ = await vm.saveArtistName()

		vm.cancelMerge()

		#expect(vm.pendingMerge == nil)
		#expect(repository.merges.isEmpty)
	}
}
