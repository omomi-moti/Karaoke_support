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
	/// 「新規」歌唱記録を保存し、紐づく ``Track`` の歌唱回数を **同一トランザクション** で 1 増やす。
	/// **新規** 記録フローでは insert はこのメソッドのみ（`singCount`・I-011 冪等と整合）。既存行の上書きは ``updateRecordingSession`` を用いる。
	/// I-011: ``SingingSession.id`` が既に存在する場合は insert・加算を行わずに成功扱い（冪等）。
	func saveNewRecordingSession(_ session: SingingSession) async throws

	/// 既存の歌唱セッションを上書きする（編集用）。``SingingSession.id`` が存在しない場合は ``SessionRepositoryError/sessionNotFound``。
	/// ``singCount`` は変更しない（新規のみ加算）。別 ``Track`` への差し替えは ``SessionRepositoryError/sessionUpdateTrackChangeNotSupported``。
	func updateRecordingSession(_ session: SingingSession) async throws

	/// 指定 id の歌唱セッションを削除する。紐づく ``Track`` の ``singCount`` を 1 減らす（0 未満にはしない）。存在しない id は ``SessionRepositoryError/sessionNotFound``。
	func deleteRecordingSession(uuid: UUID) async throws

	/// 日時降順でセッションを取得する。offset はスキップ件数（0-based）。
	/// - Parameters:
	///   - limit: 取得件数。例: 20
	///   - offset: スキップ件数。例: limit=20, offset=0 で 1〜20 件目、offset=20 で 21〜40 件目
	func fetchAll(limit: Int, offset: Int) async throws -> [SingingSession]

	/// 直近ウィンドウ内で Intent が一致するセッションを日時降順で取得する。
	///
	/// **全期間の Intent 一覧ではない。** ``SessionRecentWindow/maxSessionCount`` 件の直近セッションに対してメモリ上で絞り込む（``fetchAll(limit:offset:)`` と同一ウィンドウ）。
	func fetchByIntent(_ intent: Intent) async throws -> [SingingSession]

	/// 指定 UUID のセッションが存在するか（冪等性チェック用）。
	func exists(uuid: UUID) async throws -> Bool

	/// 編集用に id で **1件** 取得する。存在しない場合は ``SessionRepositoryError/sessionNotFound``。
	func fetchRecordingSession(uuid: UUID) async throws -> SingingSession
}
