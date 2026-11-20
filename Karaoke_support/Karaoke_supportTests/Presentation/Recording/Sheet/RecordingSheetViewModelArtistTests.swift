import Foundation
import Testing

@testable import Karaoke_support

// MARK: - Stubs

/// 渡した曲から曲名・歌手名で探し、`getOrCreate` と `fillArtistName` に渡された引数を記録する。
@MainActor
private final class ArtistTrackRepositoryStub: TrackRepositoryProtocol {
	var tracks: [Track] = []
	private(set) var getOrCreateCalls: [(name: String?, artist: String?)] = []
	private(set) var filledArtists: [(artist: String, trackId: UUID)] = []

	func searchLocal(query: String) async throws -> [Track] {
		tracks.filter { $0.userEnteredName?.localizedStandardContains(query) ?? false }
	}

	func searchLocalByArtist(query: String) async throws -> [Track] {
		tracks.filter { $0.userEnteredArtistName?.localizedStandardContains(query) ?? false }
	}

	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?, userEnteredArtistName: String?) async throws -> Track {
		getOrCreateCalls.append((userEnteredName, userEnteredArtistName))
		return Track(userEnteredName: userEnteredName ?? "曲", userEnteredArtistName: userEnteredArtistName)
	}

	func fillArtistName(_ artistName: String, trackId: UUID) async throws -> Track {
		filledArtists.append((artistName, trackId))
		return Track(id: trackId, userEnteredName: "曲", userEnteredArtistName: artistName)
	}

	func updateArtistName(_ artistName: String, trackId: UUID) async throws -> ArtistNameUpdateResult {
		.updated(Track(id: trackId, userEnteredName: "曲", userEnteredArtistName: artistName))
	}

	func mergeTrack(_ sourceId: UUID, into targetId: UUID) async throws -> Track {
		Track(id: targetId, userEnteredName: "曲")
	}

	func incrementSingCount(trackId: UUID) async throws {}
}

@MainActor
private final class ArtistSessionRepositoryStub: SessionRepositoryProtocol {
	private(set) var savedSessions: [SingingSession] = []

	func saveNewRecordingSession(_ session: SingingSession) async throws { savedSessions.append(session) }
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

// MARK: - Tests

@Suite("RecordingSheetViewModel 歌手名")
@MainActor
struct RecordingSheetViewModelArtistTests {

	private let trackRepository = ArtistTrackRepositoryStub()
	private let sessionRepository = ArtistSessionRepositoryStub()

	private func makeViewModel() -> RecordingSheetViewModel {
		let vm = RecordingSheetViewModel(trackMode: .manual, sessionRepository: sessionRepository, trackRepository: trackRepository)
		vm.suggestionDebounce = .zero
		return vm
	}

	@discardableResult
	private func addTrack(_ name: String, artist: String?, singCount: Int = 3) -> Track {
		let track = Track(userEnteredName: name, userEnteredArtistName: artist, singCount: singCount)
		trackRepository.tracks.append(track)
		return track
	}

	/// View の `.task(id:)` と同じく、入力欄を更新してから検索する。
	private func typeName(_ text: String, into vm: RecordingSheetViewModel) async {
		vm.trackState.manualName = text
		await vm.updateTrackSuggestions(for: text)
	}

	private func typeArtist(_ text: String, into vm: RecordingSheetViewModel) async {
		vm.trackState.manualArtistName = text
		await vm.updateArtistSuggestions(for: text)
	}

	private func suggestions(_ vm: RecordingSheetViewModel) -> [TrackSuggestion] {
		guard case .suggestions(let items) = vm.trackSuggestionState else { return [] }
		return items
	}

	// MARK: 候補

	@Test("歌手名を打つと、その歌手の曲を歌手名の欄の候補として出す")
	func artistSuggestionsListTracksOfArtist() async {
		addTrack("Lemon", artist: "米津玄師", singCount: 2)
		addTrack("馬と鹿", artist: "米津玄師", singCount: 5)
		addTrack("糸", artist: "中島みゆき")
		let vm = makeViewModel()

		await typeArtist("米津", into: vm)

		#expect(vm.trackSuggestionField == .artist)
		#expect(suggestions(vm).map(\.name) == ["馬と鹿", "Lemon"])
		#expect(suggestions(vm).map(\.artistName) == ["米津玄師", "米津玄師"])
	}

	@Test("曲名の欄の候補は、歌手名も持つ")
	func nameSuggestionsCarryArtist() async {
		addTrack("Lemon", artist: "米津玄師")
		let vm = makeViewModel()

		await typeName("Lem", into: vm)

		#expect(vm.trackSuggestionField == .name)
		#expect(suggestions(vm).map(\.artistName) == ["米津玄師"])
	}

	@Test("候補を押すと、曲名と歌手名の両方が入る")
	func applyingSuggestionFillsBothFields() async throws {
		addTrack("Lemon", artist: "米津玄師")
		let vm = makeViewModel()
		await typeArtist("米津", into: vm)

		vm.applyTrackSuggestion(try #require(suggestions(vm).first))

		#expect(vm.trackState.manualName == "Lemon")
		#expect(vm.trackState.manualArtistName == "米津玄師")
	}

	@Test("曲名と歌手名の両方が同じ曲があれば、歌手名の欄の候補を出さない")
	func artistSuggestionsHiddenWhenBothMatch() async {
		addTrack("Lemon", artist: "米津玄師")
		let vm = makeViewModel()
		vm.trackState.manualName = "Lemon"

		await typeArtist("米津玄師", into: vm)

		#expect(vm.trackSuggestionState == .hidden)
	}

	@Test("曲名が同じでも歌手名が違う曲は、曲名の欄の候補に出す。歌手名まで同じなら出さない")
	func nameSuggestionsDependOnArtist() async {
		addTrack("Lemon", artist: "米津玄師")
		let vm = makeViewModel()
		vm.trackState.manualArtistName = "菅田将暉"

		await typeName("Lemon", into: vm)
		#expect(suggestions(vm).map(\.artistName) == ["米津玄師"])

		vm.trackState.manualArtistName = "米津玄師"
		await typeName("Lemon", into: vm)
		#expect(vm.trackSuggestionState == .hidden)
	}

	@Test("歌手名がない曲で歌手名の欄に打っても、候補はありません")
	func artistSuggestionsNoMatch() async {
		addTrack("Lemon", artist: nil)
		let vm = makeViewModel()

		await typeArtist("米津", into: vm)

		#expect(vm.trackSuggestionState == .noMatch)
	}

	@Test("歌手名の欄では、曲の候補の上に歌手名だけの候補を、重ねずに出す。打った歌手名そのものは出さない")
	func artistNameSuggestionsAreDistinct() async {
		addTrack("Lemon", artist: "米津玄師", singCount: 2)
		addTrack("馬と鹿", artist: "米津玄師", singCount: 5)
		addTrack("米津の歌", artist: "米津バンド")
		let vm = makeViewModel()

		await typeArtist("米津", into: vm)
		#expect(Set(vm.artistNameSuggestions) == ["米津玄師", "米津バンド"])
		#expect(vm.artistNameSuggestions.count == 2)

		await typeArtist("米津玄師", into: vm)
		#expect(vm.artistNameSuggestions == [])
		#expect(suggestions(vm).map(\.name) == ["馬と鹿", "Lemon"])
	}

	@Test("歌手名が入っていれば、曲名の欄の候補はその歌手の曲を先に出し、ほかの歌手の曲も残す")
	func nameSuggestionsPutEnteredArtistFirst() async {
		addTrack("Brave", artist: "Other", singCount: 9)
		addTrack("Brave Shine", artist: "Aimer", singCount: 1)
		let vm = makeViewModel()
		vm.trackState.manualArtistName = "Aimer"

		await typeName("Bra", into: vm)

		#expect(suggestions(vm).map(\.name) == ["Brave Shine", "Brave"])
	}

	@Test("歌手名だけの候補を押すと、歌手名だけが入り、候補を閉じたままにする")
	func applyingArtistNameFillsOnlyArtist() async {
		addTrack("Lemon", artist: "米津玄師")
		let vm = makeViewModel()
		vm.trackState.manualName = "新しい曲"
		await typeArtist("米津", into: vm)

		vm.applyArtistNameSuggestion("米津玄師")
		await vm.updateArtistSuggestions(for: vm.trackState.manualArtistName)

		#expect(vm.trackState.manualName == "新しい曲")
		#expect(vm.trackState.manualArtistName == "米津玄師")
		#expect(vm.trackSuggestionState == .hidden)
	}

	@Test("歌手名だけの候補を押した後に初めての曲名で保存すると、その歌手名で新しい曲を作る")
	func artistNameThenNewTrackSaves() async {
		addTrack("Lemon", artist: "米津玄師")
		let vm = makeViewModel()
		await typeArtist("米津", into: vm)
		vm.applyArtistNameSuggestion("米津玄師")
		await typeName("さよーならまたいつか！", into: vm)

		let saved = await vm.save()

		#expect(saved != nil)
		#expect(trackRepository.getOrCreateCalls.last?.name == "さよーならまたいつか！")
		#expect(trackRepository.getOrCreateCalls.last?.artist == "米津玄師")
	}

	// MARK: 必須

	@Test("新しい曲で歌手名が空なら、保存しない")
	func newTrackRequiresArtist() async {
		let vm = makeViewModel()
		vm.trackState.manualName = "Lemon"

		let saved = await vm.save()

		#expect(saved == nil)
		#expect(vm.trackState.artistValidationMessage == "歌手名を入力してください")
		#expect(sessionRepository.savedSessions.isEmpty)
	}

	@Test("歌手名が空でも、曲名が同じで歌手名のない曲があれば、その曲に保存する")
	func emptyArtistReusesArtistlessTrack() async {
		addTrack("Lemon", artist: nil)
		let vm = makeViewModel()
		vm.trackState.manualName = "Lemon"

		let saved = await vm.save()

		#expect(saved != nil)
		#expect(trackRepository.getOrCreateCalls.map(\.artist) == [nil])
	}

	@Test("曲名と歌手名の両方が同じ曲があれば、聞かずにその曲に保存する")
	func bothMatchSavesWithoutQuestion() async {
		addTrack("Lemon", artist: nil)
		addTrack("Lemon", artist: "米津玄師")
		let vm = makeViewModel()
		vm.trackState.manualArtistName = "米津玄師"
		await typeName("Lemon", into: vm)

		#expect(vm.artistlessTrackQuestion == nil)
		let saved = await vm.save()

		#expect(saved != nil)
		#expect(trackRepository.getOrCreateCalls.map(\.artist) == ["米津玄師"])
		#expect(trackRepository.filledArtists.isEmpty)
	}

	// MARK: 歌手名のない前からの曲

	@Test("打ち切った曲名に歌手名のない同名曲があると、答えるまで保存しない")
	func artistlessMatchNeedsAnswer() async {
		let lemon = addTrack("Lemon", artist: nil, singCount: 12)
		let vm = makeViewModel()
		vm.trackState.manualName = "Lemon"
		vm.trackState.manualArtistName = "米津玄師"

		let saved = await vm.save()

		#expect(saved == nil)
		#expect(vm.artistlessTrackQuestion?.trackId == lemon.id)
		#expect(vm.isArtistlessTrackChoiceMissing)
		#expect(sessionRepository.savedSessions.isEmpty)
	}

	@Test("「同じ曲」を選ぶと、前の曲に歌手名を書き足して保存する")
	func sameTrackFillsArtist() async {
		let lemon = addTrack("Lemon", artist: nil)
		let vm = makeViewModel()
		vm.trackState.manualArtistName = "米津玄師"
		await typeName("Lemon", into: vm)

		vm.chooseArtistlessTrack(isSameTrack: true)
		let saved = await vm.save()

		#expect(saved?.trackId == lemon.id)
		#expect(trackRepository.filledArtists.map(\.artist) == ["米津玄師"])
		#expect(trackRepository.getOrCreateCalls.isEmpty)
	}

	@Test("「別の曲」を選ぶと、前の曲はそのままにして新しい曲を作る")
	func differentTrackCreatesNew() async {
		addTrack("Lemon", artist: nil)
		let vm = makeViewModel()
		vm.trackState.manualArtistName = "菅田将暉"
		await typeName("Lemon", into: vm)

		vm.chooseArtistlessTrack(isSameTrack: false)
		let saved = await vm.save()

		#expect(saved != nil)
		#expect(trackRepository.filledArtists.isEmpty)
		#expect(trackRepository.getOrCreateCalls.map(\.artist) == ["菅田将暉"])
	}

	@Test("歌手名のない曲の候補を押すと「同じ曲」を選んだ状態になり、保存で歌手名を書き足す")
	func pickingArtistlessSuggestionPresetsSameTrack() async throws {
		let lemon = addTrack("Lemon", artist: nil)
		let vm = makeViewModel()
		await typeName("Lem", into: vm)

		vm.applyTrackSuggestion(try #require(suggestions(vm).first))
		#expect(vm.currentArtistlessTrackChoice == .sameTrack(trackId: lemon.id))
		vm.trackState.manualArtistName = "米津玄師"
		let saved = await vm.save()

		#expect(saved?.trackId == lemon.id)
		#expect(trackRepository.filledArtists.map(\.trackId) == [lemon.id])
	}

	@Test("歌手名のない曲で開き、曲名を変えずに歌手名を入れて保存すると、その曲に書き足す")
	func openingArtistlessTrackPresetsSameTrack() async throws {
		let lemon = addTrack("Lemon", artist: nil)
		let selected = try #require(SelectedTrack(spotifyTrackId: nil, userEnteredName: "Lemon"))
		let vm = RecordingSheetViewModel(
			selectedTrack: selected,
			source: .selectionScreen,
			sessionRepository: sessionRepository,
			trackRepository: trackRepository
		)
		vm.suggestionDebounce = .zero

		vm.trackState.manualArtistName = "米津玄師"
		let saved = await vm.save()

		#expect(saved?.trackId == lemon.id)
		#expect(trackRepository.filledArtists.map(\.trackId) == [lemon.id])
		#expect(sessionRepository.savedSessions.first?.source == .selectionScreen)
	}

	@Test("曲名を変えると、前の曲名についての答えは使わない")
	func renamingDropsChoice() async {
		addTrack("Lemon", artist: nil)
		addTrack("糸", artist: nil)
		let vm = makeViewModel()
		vm.trackState.manualArtistName = "米津玄師"
		await typeName("Lemon", into: vm)
		vm.chooseArtistlessTrack(isSameTrack: true)

		await typeName("糸", into: vm)

		#expect(vm.artistlessTrackQuestion?.name == "糸")
		#expect(vm.currentArtistlessTrackChoice == nil)
	}

	// MARK: 閉じる前の確認

	@Test("歌手名だけを変えても、入力が変わったとみなす")
	func artistChangeCountsAsUnsaved() {
		let vm = makeViewModel()

		vm.trackState.manualArtistName = "米津玄師"

		#expect(vm.hasUnsavedChanges)
	}
}
