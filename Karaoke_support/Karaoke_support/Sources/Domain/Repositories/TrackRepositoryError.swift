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
	/// 手入力の曲ではない（Spotify 由来など）ので、歌手名を直せない。
	case notUserEnteredTrack(UUID)
	/// ``TrackRepositoryProtocol/mergeTrack(_:into:)`` で、移す元と移す先が同じ曲。
	case mergeIntoSelf(UUID)
}
