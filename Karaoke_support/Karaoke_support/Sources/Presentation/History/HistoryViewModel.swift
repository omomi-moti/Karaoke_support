import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class HistoryViewModel {
	private let sessionRepository: any SessionRepositoryProtocol

	/// 「すべて」も Intent フィルターも **同一の直近ウィンドウ**（件数上限）で揃える。
	/// Intent 絞り込みは `fetchAll` の結果をメモリ上で `filter`（直近 N 件に該当 Intent が無いと空になる仕様）。
	/// 件数は ``SessionRecentWindow/maxSessionCount`` と ``SessionRepositoryProtocol/fetchByIntent`` に合わせる。
	/// 一覧は SwiftData インスタンスではなく ``HistorySessionRowDisplayItem``（値）のみ保持する。
	var sessions: [HistorySessionRowDisplayItem] = []
	var filter: HistoryIntentFilter = .all
	var isLoading: Bool = false
	var loadErrorMessage: String?
	/// 削除失敗時のみ表示。`load()` 成功時にクリアする。
	var deleteErrorMessage: String?

	/// `.task(id:)` で前回の `load()` がキャンセルされても、古い完了が `sessions` / `loadErrorMessage` を上書きしないようにする。
	private var loadGeneration = 0

	init(sessionRepository: any SessionRepositoryProtocol) {
		self.sessionRepository = sessionRepository
	}

	func load() async {
		loadGeneration += 1
		let myGeneration = loadGeneration
		let requestedFilter = filter
		isLoading = true
		loadErrorMessage = nil
		deleteErrorMessage = nil
		defer {
			if myGeneration == loadGeneration {
				isLoading = false
			}
		}

		do {
			let rows = try await sessionRepository.fetchAll(limit: SessionRecentWindow.maxSessionCount, offset: 0)
			try Task.checkCancellation()
			guard myGeneration == loadGeneration, requestedFilter == filter else { return }
			applySessions(from: rows, for: requestedFilter)
		} catch is CancellationError {
			// キャンセル済み／古い要求: 状態は新しい `load` に任せる
		} catch {
			guard myGeneration == loadGeneration, requestedFilter == filter else { return }
			sessions = []
			loadErrorMessage = "読み込みに失敗しました。もう一度お試しください"
		}
	}

	private func applySessions(from rows: [SingingSession], for filter: HistoryIntentFilter) {
		let filtered: [SingingSession]
		switch filter {
		case .all:
			filtered = rows
		case .intent(let intent):
			filtered = rows.filter { $0.intent == intent }
		}
		sessions = filtered.map { HistorySessionRowDisplayItem(mapping: $0) }
	}

	/// 履歴から1件削除。Repository 経由（View から直接 Data を触らない）。
	///
	/// 一覧は ``HistorySessionRowDisplayItem`` のみのため、削除後も行が SwiftData fault を踏まない。
	/// それでも DB と不整合を避けるため、削除前に一覧から除外し、失敗時は `snapshot` に戻す。
	func deleteSession(id: UUID) async {
		deleteErrorMessage = nil
		let snapshot = sessions
		// 先に表示用スナップショット（値型）から除外。DB 削除の成否と独立して一覧を更新できる。
		withAnimation(nil) {
			sessions = sessions.filter { $0.id != id }
		}
		do {
			try await sessionRepository.deleteRecordingSession(uuid: id)
		} catch {
			sessions = snapshot
			deleteErrorMessage = "削除に失敗しました。もう一度お試しください"
			return
		}
		do {
			let rows = try await sessionRepository.fetchAll(limit: SessionRecentWindow.maxSessionCount, offset: 0)
			applySessions(from: rows, for: filter)
		} catch {
			// 削除は完了済みのため一覧だけ再同期
			await load()
		}
	}
}
