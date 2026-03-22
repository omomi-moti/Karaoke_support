import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class HistoryViewModel {
	private let sessionRepository: any SessionRepositoryProtocol

	/// 「すべて」も Intent フィルターも **同一の直近ウィンドウ**（件数上限）で揃える。
	/// Intent 絞り込みは `fetchAll` の結果をメモリ上で `filter`（直近 N 件に該当 Intent が無いと空になる仕様）。
	/// **適用順: `filter` → `sortOrder` による並べ替え**（I-014-B）。
	/// 件数は ``SessionRecentWindow/maxSessionCount`` と ``SessionRepositoryProtocol/fetchByIntent`` に合わせる。
	/// 一覧は SwiftData インスタンスではなく ``HistorySessionRowDisplayItem``（値）のみ保持する。
	var sessions: [HistorySessionRowDisplayItem] = []
	var filter: HistoryIntentFilter = .all
	/// 既定は歌唱日時の新しい順（`performedAt` 降順）。Repository の取得順に依存せず、表示直前に整列する。
	var sortOrder: HistorySortOrder = .performedAtDescending
	var isLoading: Bool = false
	var loadErrorMessage: String?
	/// 削除失敗時のみ表示。`load()` 成功時にクリアする。
	var deleteErrorMessage: String?

	/// `load()` / `deleteSession()` の非同期完了が交差しても、古い方が `sessions` を上書きしないようにする（V1 は単一カウンタで十分）。
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
		let items = filtered.map { HistorySessionRowDisplayItem(mapping: $0) }
		sessions = sortOrder.sorted(items)
	}

	/// `load()` 済みの一覧に対し、並び替えのみをやり直す（再フェッチなし）。
	func applySortToLoadedSessions() {
		guard !sessions.isEmpty else { return }
		sessions = sortOrder.sorted(sessions)
	}

	/// 履歴から1件削除。Repository 経由（View から直接 Data を触らない）。
	///
	/// 一覧は ``HistorySessionRowDisplayItem`` のみのため、削除後も行が SwiftData fault を踏まない。
	/// それでも DB と不整合を避けるため、削除前に一覧から除外し、失敗時は `snapshot` に戻す。
	/// ``load()`` と同じ `loadGeneration` で、フィルター変更や新しい `load` と競合した完了を捨てる。
	func deleteSession(id: UUID) async {
		deleteErrorMessage = nil
		loadGeneration += 1
		let myGeneration = loadGeneration
		let requestedFilter = filter
		let snapshot = sessions
		// 先に表示用スナップショット（値型）から除外。DB 削除の成否と独立して一覧を更新できる。
		withAnimation(nil) {
			sessions = sessions.filter { $0.id != id }
		}
		do {
			try await sessionRepository.deleteRecordingSession(uuid: id)
		} catch {
			if myGeneration == loadGeneration, requestedFilter == filter {
				sessions = snapshot
				deleteErrorMessage = "削除に失敗しました。もう一度お試しください"
			} else {
				await load()
			}
			return
		}
		guard myGeneration == loadGeneration, requestedFilter == filter else {
			await load()
			return
		}
		do {
			let rows = try await sessionRepository.fetchAll(limit: SessionRecentWindow.maxSessionCount, offset: 0)
			try Task.checkCancellation()
			guard myGeneration == loadGeneration, requestedFilter == filter else {
				await load()
				return
			}
			applySessions(from: rows, for: requestedFilter)
		} catch is CancellationError {
		} catch {
			await load()
		}
	}
}
