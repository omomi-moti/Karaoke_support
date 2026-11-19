//
//  TrackRepositoryError.swift
//  Karaoke_support
//
//  I-004: TrackRepository のエラー型。
//

import Foundation

/// TrackRepository のエラー。
enum TrackRepositoryError: Error {
	/// spotifyTrackId と userEnteredName が両方 nil または空。
	case bothIdsNil
	/// 指定 ID の Track が存在しない（incrementSingCount 等）。
	case trackNotFound(UUID)
	/// 歌手名がもう入っている曲に ``TrackRepositoryProtocol/fillArtistName(_:trackId:)`` で書こうとした。
	case artistNameAlreadySet(UUID)
	/// 書こうとした歌手名が空。
	case emptyArtistName
}
