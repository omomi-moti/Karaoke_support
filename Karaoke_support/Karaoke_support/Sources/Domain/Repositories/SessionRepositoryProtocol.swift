//
//  SessionRepositoryProtocol.swift
//  Karaoke_support
//
//  I-003: SessionRepository のプロトコル。SwiftData の具体実装に依存しない。
//

import Foundation

/// 歌唱セッションの永続化・取得を担当する Repository のプロトコル。
@MainActor
protocol SessionRepositoryProtocol {
	/// 歌唱記録を新規保存し、紐づく ``Track`` の歌唱回数を **同一トランザクション** で 1 増やす。
	/// セッションの永続化は記録フローでは **このメソッドのみ** を用いる（`singCount`・I-011 冪等と整合）。
	/// I-011: ``SingingSession.id`` が既に存在する場合は insert・加算を行わずに成功扱い（冪等）。
	func saveNewRecordingSession(_ session: SingingSession) async throws

	/// 日時降順でセッションを取得する。offset はスキップ件数（0-based）。
	/// - Parameters:
	///   - limit: 取得件数。例: 20
	///   - offset: スキップ件数。例: limit=20, offset=0 で 1〜20 件目、offset=20 で 21〜40 件目
	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession]

	/// Intent で絞り込んだセッションを取得する。
	func fetchByIntent(_ intent: Intent) async throws -> [SingingSession]

	/// 指定 UUID のセッションが存在するか（冪等性チェック用）。
	func exists(uuid: UUID) async throws -> Bool
}
