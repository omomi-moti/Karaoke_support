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
