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

	/// Intent が一致するセッションを日時降順で取得する（ページング対応）。
	///
	/// **データ範囲**: グローバルな「全期間の Intent 一覧」ではなく、実装は直近 ``SessionRecentWindow/maxSessionCount`` 件のウィンドウ上で Intent 一致に絞り、その配列に対して `offset` / `limit` を適用する（SwiftData は Predicate による Intent 絞り込みが安定しないため）。
	///
	/// - Parameters:
	///   - intent: 絞り込む Intent
	///   - limit: 取得件数。例: 20
	///   - offset: スキップ件数。例: limit=20, offset=0 で 1〜20 件目、offset=20 で 21〜40 件目
	func fetchByIntent(_ intent: Intent, limit: Int, offset: Int) async throws -> [SingingSession]

	/// 直近ウィンドウ内で Intent が一致するセッションを日時降順で取得する。
	/// ``fetchByIntent(_:limit:offset:)`` の互換 API（既定: 直近 ``SessionRecentWindow/maxSessionCount`` 件相当の offset=0）。
	func fetchByIntent(_ intent: Intent) async throws -> [SingingSession]

	/// 指定 UUID のセッションが存在するか（冪等性チェック用）。
	func exists(uuid: UUID) async throws -> Bool

	/// 編集用に id で **1件** 取得する。存在しない場合は ``SessionRepositoryError/sessionNotFound``。
	func fetchRecordingSession(uuid: UUID) async throws -> SingingSession
}

extension SessionRepositoryProtocol {
	func fetchByIntent(_ intent: Intent) async throws -> [SingingSession] {
		try await fetchByIntent(intent, limit: SessionRecentWindow.maxSessionCount, offset: 0)
	}
}
