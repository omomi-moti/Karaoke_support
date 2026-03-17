//
//  TrackRepositoryProtocol.swift
//  Karaoke_support
//
//  I-004: TrackRepository のプロトコル。SwiftData の具体実装に依存しない。
//

import Foundation

/// 楽曲（Track）の永続化・取得を担当する Repository のプロトコル。
@MainActor
protocol TrackRepositoryProtocol {
	/// userEnteredName でローカル検索。歌った回数降順。
	func searchLocal(query: String) async throws -> [Track]

	/// 既存 Track を取得するか、なければ新規作成する。両方 nil の場合は throw。
	/// - Returns: 既存または新規の Track
	func getOrCreate(spotifyTrackId: String?, userEnteredName: String?) async throws -> Track

	/// 歌唱回数を 1 増やす（集計更新）。
	func incrementSingCount(trackId: UUID) async throws
}
