//
//  TrackRepositoryProtocol.swift
//  Karaoke_support
//
//  I-004: TrackRepository のプロトコル。SwiftData の具体実装に依存しない。
//

import Foundation

/// 楽曲（Track）の永続化・取得を担当する Repository のプロトコル。
/// `@MainActor` の実装はもともと Sendable なので、Sendable を契約に入れて `any` 越しにも安全に共有できるようにする（ADR 0027）。
@MainActor
protocol TrackRepositoryProtocol: Sendable {
	/// userEnteredName でローカル検索。歌った回数降順。
	func searchLocal(query: String) async throws -> [Track]

	/// userEnteredArtistName でローカル検索。歌った回数降順。歌手名のない曲は含まない。
	func searchLocalByArtist(query: String) async throws -> [Track]

	/// 既存 Track を取得するか、なければ新規作成する。Spotify ID と曲名の両方が nil の場合は throw。
	///
	/// 手入力の曲は、曲名と歌手名の両方が完全に一致する曲を同じ曲とみなす（歌手名が空どうしも一致）。
	/// 歌手名のない前からの曲に歌手名を補うことはしない。補うのは ``fillArtistName(_:trackId:)`` だけ（ADR 0011）。
	/// - Returns: 既存または新規の Track
	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?, userEnteredArtistName: String?) async throws -> Track

	/// 歌手名のない曲に歌手名を書き足す。`updatedAt` は変えない。
	/// 歌手名がもう入っていれば ``TrackRepositoryError/artistNameAlreadySet(_:)``、空なら ``TrackRepositoryError/emptyArtistName`` を throw。
	/// - Returns: 書き足した Track
	func fillArtistName(_ artistName: String, trackId: UUID) async throws -> Track

	/// 手入力の曲の歌手名を直す。`updatedAt` は変えない。
	/// 曲名と歌手名の両方が同じ別の曲があれば、書かずに ``ArtistNameUpdateResult/conflicts(with:)`` を返す。まとめるかは本人が選び、``mergeTrack(_:into:)`` で行う。
	/// 空なら ``TrackRepositoryError/emptyArtistName``、手入力の曲でなければ ``TrackRepositoryError/notUserEnteredTrack(_:)`` を throw。
	func updateArtistName(_ artistName: String, trackId: UUID) async throws -> ArtistNameUpdateResult

	/// `sourceId` の曲の記録をすべて `targetId` の曲へ移し、歌唱回数を足して、`sourceId` の曲を消す。
	/// `createdAt` は古い方、`updatedAt` は新しい方にする。同じ曲どうしなら ``TrackRepositoryError/mergeIntoSelf(_:)`` を throw。
	/// - Returns: 記録を移した先の Track
	func mergeTrack(_ sourceId: UUID, into targetId: UUID) async throws -> Track

	/// 歌唱回数を 1 増やす（集計更新）。
	func incrementSingCount(trackId: UUID) async throws
}
