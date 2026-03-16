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
	var latestScore: Double?
	var createdAt: Date
	var updatedAt: Date

	@Relationship(deleteRule: .cascade, inverse: \SingingSession.track)
	var sessions: [SingingSession] = []

	init(
		id: UUID = UUID(),
		spotifyTrackId: String? = nil,
		userEnteredName: String? = nil,
		singCount: Int = 0,
		latestScore: Double? = nil,
		createdAt: Date = .now,
		updatedAt: Date = .now
	) {
		self.id = id
		self.spotifyTrackId = spotifyTrackId
		self.userEnteredName = userEnteredName
		self.singCount = singCount
		self.latestScore = latestScore
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}
}
