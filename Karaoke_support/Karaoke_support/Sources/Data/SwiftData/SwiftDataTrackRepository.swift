//
//  SwiftDataTrackRepository.swift
//  Karaoke_support
//
//  I-004: TrackRepository の SwiftData 実装。
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataTrackRepository: TrackRepositoryProtocol {
	private let modelContext: ModelContext

	init(modelContext: ModelContext) {
		self.modelContext = modelContext
	}

	func searchLocal(query: String) async throws -> [Track] {
		guard !query.isEmpty else {
			return []
		}
		let searchQuery = query

		let descriptor = FetchDescriptor<Track>(
			predicate: #Predicate<Track> { track in
				if let name = track.userEnteredName {
					name.localizedStandardContains(searchQuery)
				} else {
					false
				}
			},
			sortBy: [SortDescriptor(\.singCount, order: .reverse)]
		)
		return try modelContext.fetch(descriptor)
	}

	func searchLocalByArtist(query: String) async throws -> [Track] {
		guard !query.isEmpty else {
			return []
		}
		let searchQuery = query

		let descriptor = FetchDescriptor<Track>(
			predicate: #Predicate<Track> { track in
				if let artist = track.userEnteredArtistName {
					artist.localizedStandardContains(searchQuery)
				} else {
					false
				}
			},
			sortBy: [SortDescriptor(\.singCount, order: .reverse)]
		)
		return try modelContext.fetch(descriptor)
	}

	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?, userEnteredArtistName: String?) async throws -> Track {
		let hasSpotify = spotifyTrackId.map { !$0.isEmpty } ?? false
		let hasUser = userEnteredName.map { !$0.isEmpty } ?? false

		guard hasSpotify || hasUser else {
			throw TrackRepositoryError.bothIdsNil
		}

		if let sid = spotifyTrackId, !sid.isEmpty {
			if let existing = try fetchBySpotifyTrackId(sid) {
				return existing
			}
			// Spotify 由来では userEnteredName を永続化しない（API 規約準拠）
			let track = Track(spotifyTrackId: sid, userEnteredName: nil)
			modelContext.insert(track)
			do {
				try modelContext.save()
				return track
			} catch {
				modelContext.delete(track)
				throw error
			}
		}

		if let name = userEnteredName, !name.isEmpty {
			let artist = userEnteredArtistName.flatMap { $0.isEmpty ? nil : $0 }
			if let existing = try fetchByUserEnteredName(name, artistName: artist) {
				return existing
			}
			let track = Track(userEnteredName: name, userEnteredArtistName: artist, spotifyTrackId: nil)
			modelContext.insert(track)
			do {
				try modelContext.save()
				return track
			} catch {
				modelContext.delete(track)
				throw error
			}
		}

		throw TrackRepositoryError.bothIdsNil
	}

	func fillArtistName(_ artistName: String, trackId: UUID) async throws -> Track {
		guard !artistName.isEmpty else {
			throw TrackRepositoryError.emptyArtistName
		}
		guard let track = try fetchById(trackId) else {
			throw TrackRepositoryError.trackNotFound(trackId)
		}
		guard track.userEnteredArtistName?.isEmpty ?? true else {
			throw TrackRepositoryError.artistNameAlreadySet(trackId)
		}
		track.userEnteredArtistName = artistName
		do {
			try modelContext.save()
			return track
		} catch {
			modelContext.rollback()
			throw error
		}
	}

	func incrementSingCount(trackId: UUID) async throws {
		guard let track = try fetchById(trackId) else {
			throw TrackRepositoryError.trackNotFound(trackId)
		}
		track.singCount += 1
		track.updatedAt = .now
		try modelContext.save()
	}

	// MARK: - Private

	private func fetchBySpotifyTrackId(_ spotifyTrackId: String) throws -> Track? {
		let idToMatch = spotifyTrackId
		var descriptor = FetchDescriptor<Track>(
			predicate: #Predicate<Track> { $0.spotifyTrackId == idToMatch }
		)
		descriptor.fetchLimit = 1
		return try modelContext.fetch(descriptor).first
	}

	/// 歌手名は空どうしも一致とみなす。空の値との比べ方を SQL への変換に任せず、曲名で絞ってからメモリで比べる。
	private func fetchByUserEnteredName(_ userEnteredName: String, artistName: String?) throws -> Track? {
		let nameToMatch = userEnteredName
		let descriptor = FetchDescriptor<Track>(
			predicate: #Predicate<Track> { track in
				track.spotifyTrackId == nil && track.userEnteredName == nameToMatch
			}
		)
		return try modelContext.fetch(descriptor).first { track in
			TrackDisplayTitle.artist(userEnteredArtistName: track.userEnteredArtistName) == artistName
		}
	}

	private func fetchById(_ id: UUID) throws -> Track? {
		let idToMatch = id
		var descriptor = FetchDescriptor<Track>(
			predicate: #Predicate<Track> { $0.id == idToMatch }
		)
		descriptor.fetchLimit = 1
		return try modelContext.fetch(descriptor).first
	}
}
