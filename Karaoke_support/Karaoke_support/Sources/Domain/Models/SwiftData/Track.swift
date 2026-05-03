//
//  Track.swift
//  Karaoke_support
//

import Foundation
import SwiftData

// Why: Spotify API規約により、曲名・アーティスト名・アートワーク等の永続保存が禁止されているため。
// 永続化するのは Track ID と集計情報のみ。表示用メタデータは API または一時キャッシュから取得する。
@Model
final class Track {
	@Attribute(.unique) var id: UUID
	var spotifyTrackId: String?
	/// 手動入力曲用。ユーザーが入力した曲名（ユーザー生成データのため永続化可）。Spotify メタデータではない。
	var userEnteredName: String?
	var singCount: Int
	var createdAt: Date
	var updatedAt: Date

	@Relationship(deleteRule: .cascade, inverse: \SingingSession.track)
	var sessions: [SingingSession] = []

	/// 代入ロジックの単一化用。呼び出しは 2 本の public init からのみ。
	private init(
		id: UUID,
		spotifyTrackId: String?,
		userEnteredName: String?,
		singCount: Int,
		createdAt: Date,
		updatedAt: Date
	) {
		self.id = id
		self.spotifyTrackId = spotifyTrackId
		self.userEnteredName = userEnteredName
		self.singCount = singCount
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}

	/// Spotify 由来の曲用。`spotifyTrackId` 必須。
	convenience init(
		id: UUID = UUID(),
		spotifyTrackId: String,
		userEnteredName: String? = nil,
		singCount: Int = 0,
		createdAt: Date = .now,
		updatedAtOverride: Date? = nil
	) {
		precondition(!spotifyTrackId.isEmpty, "spotifyTrackId must be non-empty.")
		let resolvedUpdatedAt = updatedAtOverride ?? createdAt
		self.init(
			id: id,
			spotifyTrackId: spotifyTrackId,
			userEnteredName: userEnteredName,
			singCount: singCount,
			createdAt: createdAt,
			updatedAt: resolvedUpdatedAt
		)
	}

	/// 手動入力曲用。`userEnteredName` 必須。
	convenience init(
		id: UUID = UUID(),
		userEnteredName: String,
		spotifyTrackId: String? = nil,
		singCount: Int = 0,
		createdAt: Date = .now,
		updatedAtOverride: Date? = nil
	) {
		precondition(!userEnteredName.isEmpty, "userEnteredName must be non-empty.")
		let resolvedUpdatedAt = updatedAtOverride ?? createdAt
		self.init(
			id: id,
			spotifyTrackId: spotifyTrackId,
			userEnteredName: userEnteredName,
			singCount: singCount,
			createdAt: createdAt,
			updatedAt: resolvedUpdatedAt
		)
	}
}
