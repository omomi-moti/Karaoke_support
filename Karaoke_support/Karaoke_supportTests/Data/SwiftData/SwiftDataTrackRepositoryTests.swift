import Foundation
import SwiftData
import Testing

@testable import Karaoke_support

@Suite("SwiftDataTrackRepository の歌手名")
@MainActor
struct SwiftDataTrackRepositoryTests {

	private let context: ModelContext
	private let repository: SwiftDataTrackRepository

	init() throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		context = ModelContext(container)
		repository = SwiftDataTrackRepository(modelContext: context)
	}

	private func insertTrack(_ name: String, artist: String?, singCount: Int = 1) throws -> Track {
		let track = Track(userEnteredName: name, userEnteredArtistName: artist, singCount: singCount)
		context.insert(track)
		try context.save()
		return track
	}

	private func allTracks() throws -> [Track] {
		try context.fetch(FetchDescriptor<Track>())
	}

	// MARK: - getOrCreate

	@Test("曲名と歌手名の両方が同じなら、前からの曲を返す")
	func getOrCreate_sameNameAndArtist_returnsExisting() async throws {
		let existing = try insertTrack("Lemon", artist: "米津玄師")

		let track = try await repository.getOrCreate(spotifyTrackId: nil, userEnteredName: "Lemon", userEnteredArtistName: "米津玄師")

		#expect(track.id == existing.id)
		#expect(try allTracks().count == 1)
	}

	@Test("曲名が同じでも歌手名が違えば、別の曲を作る")
	func getOrCreate_differentArtist_createsNew() async throws {
		let existing = try insertTrack("Lemon", artist: "米津玄師")

		let track = try await repository.getOrCreate(spotifyTrackId: nil, userEnteredName: "Lemon", userEnteredArtistName: "菅田将暉")

		#expect(track.id != existing.id)
		#expect(track.userEnteredArtistName == "菅田将暉")
		#expect(try allTracks().count == 2)
	}

	@Test("歌手名が空どうしは同じ曲とみなす")
	func getOrCreate_bothArtistNil_returnsExisting() async throws {
		let existing = try insertTrack("Lemon", artist: nil)

		let track = try await repository.getOrCreate(spotifyTrackId: nil, userEnteredName: "Lemon", userEnteredArtistName: nil)

		#expect(track.id == existing.id)
	}

	@Test("歌手名のない前からの曲には補わず、歌手名付きの新しい曲を作る")
	func getOrCreate_artistlessExisting_doesNotFill() async throws {
		let existing = try insertTrack("Lemon", artist: nil)

		let track = try await repository.getOrCreate(spotifyTrackId: nil, userEnteredName: "Lemon", userEnteredArtistName: "米津玄師")

		#expect(track.id != existing.id)
		#expect(existing.userEnteredArtistName == nil)
	}

	@Test("空の歌手名は、歌手名なしとして扱う")
	func getOrCreate_emptyArtist_treatedAsNil() async throws {
		let existing = try insertTrack("Lemon", artist: nil)

		let track = try await repository.getOrCreate(spotifyTrackId: nil, userEnteredName: "Lemon", userEnteredArtistName: "")

		#expect(track.id == existing.id)
	}

	// MARK: - fillArtistName

	@Test("歌手名のない曲に書き足し、updatedAt は変えない")
	func fillArtistName_artistless_fills() async throws {
		let existing = try insertTrack("Lemon", artist: nil)
		let updatedAt = existing.updatedAt

		let track = try await repository.fillArtistName("米津玄師", trackId: existing.id)

		#expect(track.id == existing.id)
		#expect(track.userEnteredArtistName == "米津玄師")
		#expect(track.updatedAt == updatedAt)
	}

	@Test("歌手名がもう入っている曲には書かない")
	func fillArtistName_alreadySet_throws() async throws {
		let existing = try insertTrack("Lemon", artist: "米津玄師")

		await #expect(throws: TrackRepositoryError.self) {
			_ = try await repository.fillArtistName("菅田将暉", trackId: existing.id)
		}
		#expect(existing.userEnteredArtistName == "米津玄師")
	}

	@Test("空の歌手名は書かない")
	func fillArtistName_empty_throws() async throws {
		let existing = try insertTrack("Lemon", artist: nil)

		await #expect(throws: TrackRepositoryError.self) {
			_ = try await repository.fillArtistName("", trackId: existing.id)
		}
		#expect(existing.userEnteredArtistName == nil)
	}

	// MARK: - updateArtistName

	@Test("歌手名を直し、updatedAt は変えない")
	func updateArtistName_noConflict_updates() async throws {
		let existing = try insertTrack("Lemon", artist: "米津元師")
		let updatedAt = existing.updatedAt

		let result = try await repository.updateArtistName("米津玄師", trackId: existing.id)

		guard case .updated(let track) = result else {
			Issue.record("直せていない: \(result)")
			return
		}
		#expect(track.id == existing.id)
		#expect(track.userEnteredArtistName == "米津玄師")
		#expect(track.updatedAt == updatedAt)
	}

	@Test("歌手名のない曲にも付けられる")
	func updateArtistName_artistless_updates() async throws {
		let existing = try insertTrack("Lemon", artist: nil)

		let result = try await repository.updateArtistName("米津玄師", trackId: existing.id)

		guard case .updated = result else {
			Issue.record("直せていない: \(result)")
			return
		}
		#expect(existing.userEnteredArtistName == "米津玄師")
	}

	@Test("曲名と歌手名の両方が同じ別の曲があれば、書かずにその曲を返す")
	func updateArtistName_conflict_returnsOtherWithoutWriting() async throws {
		let typo = try insertTrack("Lemon", artist: "米津元師")
		let correct = try insertTrack("Lemon", artist: "米津玄師")

		let result = try await repository.updateArtistName("米津玄師", trackId: typo.id)

		guard case .conflicts(let other) = result else {
			Issue.record("重なりを返していない: \(result)")
			return
		}
		#expect(other.id == correct.id)
		#expect(typo.userEnteredArtistName == "米津元師")
	}

	@Test("曲名が同じでも歌手名が違う曲とは重ならない")
	func updateArtistName_sameNameOtherArtist_updates() async throws {
		let existing = try insertTrack("Lemon", artist: "米津元師")
		_ = try insertTrack("Lemon", artist: "菅田将暉")

		let result = try await repository.updateArtistName("米津玄師", trackId: existing.id)

		guard case .updated = result else {
			Issue.record("直せていない: \(result)")
			return
		}
		#expect(existing.userEnteredArtistName == "米津玄師")
	}

	@Test("今と同じ歌手名なら、そのまま返す")
	func updateArtistName_unchanged_returnsSelf() async throws {
		let existing = try insertTrack("Lemon", artist: "米津玄師")

		let result = try await repository.updateArtistName("米津玄師", trackId: existing.id)

		guard case .updated(let track) = result else {
			Issue.record("自分と重なったとみなしている: \(result)")
			return
		}
		#expect(track.id == existing.id)
	}

	@Test("空の歌手名にはできない")
	func updateArtistName_empty_throws() async throws {
		let existing = try insertTrack("Lemon", artist: "米津玄師")

		await #expect(throws: TrackRepositoryError.self) {
			_ = try await repository.updateArtistName("", trackId: existing.id)
		}
		#expect(existing.userEnteredArtistName == "米津玄師")
	}

	@Test("Spotify 由来の曲は直せない")
	func updateArtistName_spotifyTrack_throws() async throws {
		let track = Track(spotifyTrackId: "spotify:track:abc")
		context.insert(track)
		try context.save()

		await #expect(throws: TrackRepositoryError.self) {
			_ = try await repository.updateArtistName("米津玄師", trackId: track.id)
		}
		#expect(track.userEnteredArtistName == nil)
	}

	@Test("ない曲は直せない")
	func updateArtistName_missing_throws() async throws {
		await #expect(throws: TrackRepositoryError.self) {
			_ = try await repository.updateArtistName("米津玄師", trackId: UUID())
		}
	}

	// MARK: - mergeTrack

	@Test("記録を移して回数を足し、元の曲を消す。作った日は古い方、更新日は新しい方")
	func mergeTrack_movesSessionsAndDeletesSource() async throws {
		let old = Date(timeIntervalSince1970: 1_000)
		let new = Date(timeIntervalSince1970: 2_000)
		let source = Track(userEnteredName: "Lemon", userEnteredArtistName: "米津元師", singCount: 2, createdAt: old, updatedAtOverride: new)
		let target = Track(userEnteredName: "Lemon", userEnteredArtistName: "米津玄師", singCount: 3, createdAt: new, updatedAtOverride: new.addingTimeInterval(-500))
		context.insert(source)
		context.insert(target)
		let movedA = SingingSession(track: source, intent: .shout, score: 80)
		let movedB = SingingSession(track: source, intent: .emo, score: nil)
		let kept = SingingSession(track: target, intent: .practice, score: 90)
		[movedA, movedB, kept].forEach(context.insert)
		try context.save()
		let sourceId = source.id

		let merged = try await repository.mergeTrack(sourceId, into: target.id)

		#expect(merged.id == target.id)
		#expect(merged.singCount == 5)
		#expect(merged.createdAt == old)
		#expect(merged.updatedAt == new)
		#expect(Set(merged.sessions.map(\.id)) == Set([movedA.id, movedB.id, kept.id]))
		#expect(try allTracks().map(\.id) == [target.id])
		#expect(try context.fetch(FetchDescriptor<SingingSession>()).count == 3)
	}

	@Test("同じ曲どうしはまとめない")
	func mergeTrack_self_throws() async throws {
		let track = try insertTrack("Lemon", artist: "米津玄師", singCount: 2)

		await #expect(throws: TrackRepositoryError.self) {
			_ = try await repository.mergeTrack(track.id, into: track.id)
		}
		#expect(track.singCount == 2)
		#expect(try allTracks().count == 1)
	}

	@Test("移す先がなければ、何も変えない")
	func mergeTrack_missingTarget_throws() async throws {
		let source = try insertTrack("Lemon", artist: "米津元師")

		await #expect(throws: TrackRepositoryError.self) {
			_ = try await repository.mergeTrack(source.id, into: UUID())
		}
		#expect(try allTracks().map(\.id) == [source.id])
	}

	// MARK: - searchLocalByArtist

	@Test("歌手名の部分一致で、歌唱回数の多い順に返す。歌手名のない曲は含まない")
	func searchLocalByArtist_matchesArtist() async throws {
		_ = try insertTrack("Lemon", artist: "米津玄師", singCount: 2)
		_ = try insertTrack("馬と鹿", artist: "米津玄師", singCount: 5)
		_ = try insertTrack("米津", artist: nil)
		_ = try insertTrack("糸", artist: "中島みゆき")

		let found = try await repository.searchLocalByArtist(query: "米津")

		#expect(found.map(\.userEnteredName) == ["馬と鹿", "Lemon"])
	}
}
