import Foundation
import Testing

@testable import Karaoke_support

// MARK: - Stubs

/// `searchLocal` の戻り値・呼び出しと、`getOrCreate` に渡された引数を記録する。
@MainActor
private final class SuggestionTrackRepositoryStub: TrackRepositoryProtocol {
	var tracksToReturn: [Track] = []
	var errorToThrow: Error?
	private(set) var searchQueries: [String] = []
	private(set) var getOrCreateNames: [String?] = []

	func searchLocal(query: String) async throws -> [Track] {
		searchQueries.append(query)
		if let errorToThrow {
			throw errorToThrow
		}
		return tracksToReturn
	}

	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?) async throws -> Track {
		getOrCreateNames.append(userEnteredName)
		return Track(userEnteredName: userEnteredName ?? "fallback")
	}

	func incrementSingCount(trackId: UUID) async throws {}
}

/// `searchLocal` を継続で止め、キャンセルや入力の置き換えの後に遅れて返る状況を作る。
@MainActor
private final class GatedTrackRepositoryStub: TrackRepositoryProtocol {
	var tracksToReturn: [Track] = []
	/// 止めた検索を再開したときに投げるエラー。`nil` なら `tracksToReturn` を返す。
	var errorToThrow: Error?
	/// この回数だけは止めずにすぐ返す（先に候補を出しておくため）。
	var immediateSearchCount = 0
	private var searchCount = 0
	private var resumeSearch: CheckedContinuation<Void, Never>?
	private var notifyStarted: CheckedContinuation<Void, Never>?
	private var didStartSearch = false

	func searchLocal(query: String) async throws -> [Track] {
		searchCount += 1
		if searchCount <= immediateSearchCount {
			return tracksToReturn
		}
		didStartSearch = true
		notifyStarted?.resume()
		notifyStarted = nil
		await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
			resumeSearch = c
		}
		if let errorToThrow {
			throw errorToThrow
		}
		return tracksToReturn
	}

	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?) async throws -> Track {
		Track(userEnteredName: userEnteredName ?? "fallback")
	}

	func incrementSingCount(trackId: UUID) async throws {}

	func waitUntilSearchStarted() async {
		if didStartSearch { return }
		await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
			notifyStarted = c
		}
	}

	func finishSearch() {
		resumeSearch?.resume()
		resumeSearch = nil
	}
}

@MainActor
private final class NoopSessionRepositoryStub: SessionRepositoryProtocol {
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

// MARK: - Tests

@Suite("RecordingSheetViewModel 曲名サジェスト")
@MainActor
struct RecordingSheetViewModelSuggestionTests {

	private func makeViewModel(trackRepository: any TrackRepositoryProtocol) -> RecordingSheetViewModel {
		let vm = RecordingSheetViewModel(
			trackMode: .manual,
			sessionRepository: NoopSessionRepositoryStub(),
			trackRepository: trackRepository
		)
		vm.suggestionDebounce = .zero
		return vm
	}

	private func makeTrack(_ name: String, singCount: Int) -> Track {
		Track(userEnteredName: name, singCount: singCount)
	}

	/// View の `.task(id: manualName)` と同じく、入力欄を更新してから検索する。
	private func type(_ text: String, into vm: RecordingSheetViewModel) async {
		vm.trackState.manualName = text
		await vm.updateTrackSuggestions(for: text)
	}

	private func suggestedNames(_ vm: RecordingSheetViewModel) -> [String] {
		guard case .suggestions(let items) = vm.trackSuggestionState else { return [] }
		return items.map(\.name)
	}

	// MARK: 検索

	@Test("空白だけの入力では検索せず、何も出さない", arguments: ["", "   ", "\n\t"])
	func blankQueryDoesNotSearch(query: String) async {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 3)]
		let vm = makeViewModel(trackRepository: stub)

		await type(query, into: vm)

		#expect(stub.searchQueries.isEmpty)
		#expect(vm.trackSuggestionState == .hidden)
	}

	@Test("前後の空白を除いた文字列で検索する")
	func queryIsTrimmedBeforeSearch() async {
		let stub = SuggestionTrackRepositoryStub()
		let vm = makeViewModel(trackRepository: stub)

		await type("  れもん ", into: vm)

		#expect(stub.searchQueries == ["れもん"])
	}

	@Test("大文字小文字が違う入力に、既存の曲名を「もしかして」で出す")
	func caseDifferentInputSuggestsExistingName() async {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 12)]
		let vm = makeViewModel(trackRepository: stub)

		await type("lemon", into: vm)

		#expect(suggestedNames(vm) == ["Lemon"])
	}

	@Test("候補は最大 5 件で、同じ段の中では歌唱回数の多い順")
	func suggestionsAreLimitedAndSortedBySingCount() async {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = (1 ... 7).reversed().map { makeTrack("曲\($0)", singCount: $0) }
		let vm = makeViewModel(trackRepository: stub)

		await type("曲", into: vm)

		guard case .suggestions(let items) = vm.trackSuggestionState else {
			Issue.record("候補が出ていない: \(vm.trackSuggestionState)")
			return
		}
		#expect(items.count == RecordingSheetViewModel.maxTrackSuggestions)
		#expect(items.map(\.singCount) == [7, 6, 5, 4, 3])
	}

	@Test("5 件に絞る前に並べ替えるので、回数順で 6 件目以降の前方一致の曲も先頭に来る")
	func rankingHappensBeforeLimiting() async {
		let stub = SuggestionTrackRepositoryStub()
		// searchLocal は歌唱回数の多い順に返す。部分一致の 6 曲のあとに、前方一致の曲が来る
		stub.tracksToReturn = (5 ... 10).reversed().map { makeTrack("ole\($0)", singCount: $0) }
			+ [makeTrack("lemon", singCount: 1)]
		let vm = makeViewModel(trackRepository: stub)

		await type("le", into: vm)

		guard case .suggestions(let items) = vm.trackSuggestionState else {
			Issue.record("候補が出ていない: \(vm.trackSuggestionState)")
			return
		}
		#expect(items.count == RecordingSheetViewModel.maxTrackSuggestions)
		#expect(items.first?.name == "lemon")
	}

	@Test("歌唱回数 0 の曲（記録を全部消した曲）は候補に出さない")
	func zeroSingCountTracksAreExcluded() async {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 2), makeTrack("Lemn", singCount: 0)]
		let vm = makeViewModel(trackRepository: stub)

		await type("Lem", into: vm)

		#expect(suggestedNames(vm) == ["Lemon"])
	}

	// MARK: 候補なし・非表示

	@Test("1 文字でも、一致する曲がなければ「候補はありません」の状態になる")
	func noMatchingTrackBecomesNoMatch() async {
		let stub = SuggestionTrackRepositoryStub()
		let vm = makeViewModel(trackRepository: stub)

		await type("ま", into: vm)

		#expect(stub.searchQueries == ["ま"])
		#expect(vm.trackSuggestionState == .noMatch)
	}

	@Test("歌唱回数 0 の曲しか一致しないときも「候補はありません」の状態になる")
	func onlyZeroSingCountMatchBecomesNoMatch() async {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemn", singCount: 0)]
		let vm = makeViewModel(trackRepository: stub)

		await type("Lem", into: vm)

		#expect(vm.trackSuggestionState == .noMatch)
	}

	@Test("入力が既存の曲名と完全一致なら、何も出さない（既存の曲につながるため）")
	func exactMatchHidesSuggestions() async {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 12), makeTrack("Lemon (Live)", singCount: 3)]
		let vm = makeViewModel(trackRepository: stub)

		await type("Lemon", into: vm)

		#expect(vm.trackSuggestionState == .hidden)
	}

	@Test("歌唱回数 0 の曲と完全一致なら、候補から除いた曲でも既存の曲につながるので何も出さない")
	func exactMatchWithZeroSingCountTrackHides() async {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 0)]
		let vm = makeViewModel(trackRepository: stub)

		await type("Lemon", into: vm)

		#expect(vm.trackSuggestionState == .hidden)
	}

	@Test("Spotify ID を持つ曲は、押しても手入力の保存で既存の曲につながらないので候補に出さない")
	func tracksWithSpotifyIdAreExcluded() async {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [
			Track(spotifyTrackId: "spotify-lemon", userEnteredName: "Lemon", singCount: 5),
			makeTrack("Lemonade", singCount: 1),
		]
		let vm = makeViewModel(trackRepository: stub)

		await type("Lem", into: vm)

		#expect(suggestedNames(vm) == ["Lemonade"])
	}

	@Test("Spotify ID を持つ曲と曲名が完全一致しても、既存の曲にはつながらないので非表示にしない")
	func exactMatchWithSpotifyTrackDoesNotHide() async {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [Track(spotifyTrackId: "spotify-lemon", userEnteredName: "Lemon", singCount: 5)]
		let vm = makeViewModel(trackRepository: stub)

		await type("Lemon", into: vm)

		#expect(vm.trackSuggestionState == .noMatch)
	}

	@Test("「候補はありません」のあと入力を空にすると、すぐ非表示になる")
	func clearingInputAfterNoMatchHides() async {
		let stub = SuggestionTrackRepositoryStub()
		let vm = makeViewModel(trackRepository: stub)
		await type("ま", into: vm)
		#expect(vm.trackSuggestionState == .noMatch)

		await type("", into: vm)

		#expect(vm.trackSuggestionState == .hidden)
	}

	@Test("検索に失敗したら「候補はありません」ではなく非表示にし、エラー表示も出さない")
	func searchFailureHidesSilently() async {
		struct StubError: Error {}
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 1)]
		let vm = makeViewModel(trackRepository: stub)
		await type("Le", into: vm)
		#expect(suggestedNames(vm) == ["Lemon"])

		stub.errorToThrow = StubError()
		await type("Lem", into: vm)

		#expect(vm.trackSuggestionState == .hidden)
		#expect(vm.inlineErrorMessage == nil)
	}

	// MARK: 古い候補（入力が変わってから新しい結果が出るまで）

	@Test("候補を出した入力のままなら、候補は古い扱いにならない")
	func suggestionsForCurrentInputAreNotStale() async {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 4)]
		let vm = makeViewModel(trackRepository: stub)

		await type("lem", into: vm)

		#expect(vm.isTrackSuggestionStale == false)
	}

	@Test("入力が変わると、新しい結果が出るまで候補は古い扱いになる")
	func suggestionsBecomeStaleWhenInputChanges() async {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 4)]
		let vm = makeViewModel(trackRepository: stub)
		await type("lem", into: vm)

		// `.task(id:)` の待ち時間中（まだ新しい検索結果が出ていない）
		vm.trackState.manualName = "lemx"

		#expect(suggestedNames(vm) == ["Lemon"])
		#expect(vm.isTrackSuggestionStale)
	}

	@Test("前後の空白だけが変わっても、候補は古い扱いにならない")
	func whitespaceOnlyChangeDoesNotMakeStale() async {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 4)]
		let vm = makeViewModel(trackRepository: stub)
		await type("lem", into: vm)

		vm.trackState.manualName = "lem "

		#expect(vm.isTrackSuggestionStale == false)
	}

	@Test("新しい検索結果が出れば、古い扱いは解ける")
	func newResultClearsStale() async {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 4)]
		let vm = makeViewModel(trackRepository: stub)
		await type("lem", into: vm)
		vm.trackState.manualName = "lemo"
		#expect(vm.isTrackSuggestionStale)

		await vm.updateTrackSuggestions(for: "lemo")

		#expect(vm.isTrackSuggestionStale == false)
	}

	@Test("「候補はありません」も、入力が変わると新しい結果が出るまで古い扱いになる")
	func noMatchBecomesStaleWhenInputChanges() async {
		let stub = SuggestionTrackRepositoryStub()
		let vm = makeViewModel(trackRepository: stub)
		await type("ま", into: vm)
		#expect(vm.trackSuggestionState == .noMatch)
		#expect(vm.isTrackSuggestionStale == false)

		vm.trackState.manualName = "まり"

		#expect(vm.trackSuggestionState == .noMatch)
		#expect(vm.isTrackSuggestionStale)
	}

	@Test("検索中に入力が置き換わったら、その検索のエラーで今の表示を上書きしない")
	func errorForReplacedInputDoesNotOverwrite() async {
		struct StubError: Error {}
		let stub = GatedTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 1)]
		stub.immediateSearchCount = 1
		let vm = makeViewModel(trackRepository: stub)
		await type("Le", into: vm)
		#expect(suggestedNames(vm) == ["Lemon"])

		stub.errorToThrow = StubError()
		vm.trackState.manualName = "Lem"
		let search = Task { await vm.updateTrackSuggestions(for: "Lem") }
		await stub.waitUntilSearchStarted()
		// `.task` のキャンセルが届く前に、さらに入力が変わった状況
		vm.trackState.manualName = "Lemo"
		stub.finishSearch()
		await search.value

		#expect(suggestedNames(vm) == ["Lemon"])
	}

	@Test("古い候補は押しても適用されない")
	func staleSuggestionIsNotApplied() async throws {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 4)]
		let vm = makeViewModel(trackRepository: stub)
		await type("lem", into: vm)
		guard case .suggestions(let items) = vm.trackSuggestionState else {
			Issue.record("候補が出ていない: \(vm.trackSuggestionState)")
			return
		}
		vm.trackState.manualName = "lemx"

		vm.applyTrackSuggestion(try #require(items.first))

		#expect(vm.trackState.manualName == "lemx")
	}

	// MARK: 候補の適用・保存

	@Test("候補を押すと入力欄が置き換わり、手入力のまま候補が消える")
	func applyingSuggestionReplacesManualName() async throws {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 4)]
		let vm = makeViewModel(trackRepository: stub)
		await type("lem", into: vm)
		guard case .suggestions(let items) = vm.trackSuggestionState else {
			Issue.record("候補が出ていない: \(vm.trackSuggestionState)")
			return
		}

		vm.applyTrackSuggestion(try #require(items.first))

		#expect(vm.trackState.manualName == "Lemon")
		#expect(vm.trackState.mode == .manual)
		#expect(vm.trackSuggestionState == .hidden)
	}

	@Test("候補を押して保存すると、入力途中の文字列ではなく既存の曲名が getOrCreate に渡る")
	func savingAfterApplyingPassesExistingName() async throws {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 4)]
		let vm = makeViewModel(trackRepository: stub)
		await type("lem", into: vm)
		guard case .suggestions(let items) = vm.trackSuggestionState else {
			Issue.record("候補が出ていない: \(vm.trackSuggestionState)")
			return
		}
		vm.applyTrackSuggestion(try #require(items.first))

		let ok = await vm.save()

		#expect(ok)
		#expect(stub.getOrCreateNames == ["Lemon"])
	}

	// MARK: 古い結果の破棄

	@Test("キャンセルされた検索の結果は反映しない")
	func cancelledSearchResultIsDiscarded() async {
		let stub = GatedTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 1)]
		let vm = makeViewModel(trackRepository: stub)
		vm.trackState.manualName = "Le"

		let search = Task { await vm.updateTrackSuggestions(for: "Le") }
		await stub.waitUntilSearchStarted()
		search.cancel()
		stub.finishSearch()
		await search.value

		#expect(vm.trackSuggestionState == .hidden)
	}

	@Test("検索中に入力欄が置き換わったら、その検索結果は捨てる")
	func searchResultForReplacedInputIsDiscarded() async {
		let stub = GatedTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 1)]
		let vm = makeViewModel(trackRepository: stub)
		vm.trackState.manualName = "Le"

		let search = Task { await vm.updateTrackSuggestions(for: "Le") }
		await stub.waitUntilSearchStarted()
		// 候補タップ直後など、`.task` のキャンセルが届く前に入力が変わった状況
		vm.trackState.manualName = "Lemon"
		stub.finishSearch()
		await search.value

		#expect(vm.trackSuggestionState == .hidden)
	}

	// MARK: 候補を出さない画面状態

	@Test("曲名入りで開いたとき（ランキング・検索タブから）は、完全一致なので何も出さない")
	func openingWithSelectedTrackShowsNothing() async throws {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 4)]
		let selected = try #require(SelectedTrack(spotifyTrackId: nil, userEnteredName: "Lemon"))
		let vm = RecordingSheetViewModel(
			selectedTrack: selected,
			sessionRepository: NoopSessionRepositoryStub(),
			trackRepository: stub
		)
		vm.suggestionDebounce = .zero

		await vm.updateTrackSuggestions(for: vm.trackState.manualName)

		#expect(vm.trackSuggestionState == .hidden)
	}

	@Test("既存記録の編集中は検索しない")
	func editingSessionDisablesSuggestions() async {
		let stub = SuggestionTrackRepositoryStub()
		stub.tracksToReturn = [makeTrack("Lemon", singCount: 4)]
		let session = SingingSession(track: makeTrack("編集中", singCount: 1), intent: .emo, score: 80)
		let vm = RecordingSheetViewModel(
			editingSession: session,
			sessionRepository: NoopSessionRepositoryStub(),
			trackRepository: stub
		)
		vm.suggestionDebounce = .zero

		await vm.updateTrackSuggestions(for: "Le")

		#expect(stub.searchQueries.isEmpty)
		#expect(vm.trackSuggestionState == .hidden)
	}
}
