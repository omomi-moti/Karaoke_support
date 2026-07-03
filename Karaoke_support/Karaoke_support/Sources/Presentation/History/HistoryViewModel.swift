import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class HistoryViewModel {
	private let sessionRepository: any SessionRepositoryProtocol

	/// 一覧は 20 件単位でページングする（I-015）。
	/// `filter` は Repository の取得条件として先に適用し、その結果を `sortOrder` で並べ替える。
	/// 並び替えは取得済みページの範囲に対して適用する。
	/// 一覧は SwiftData インスタンスではなく ``HistorySessionRowDisplayItem``（値）のみ保持する。
	var sessions: [HistorySessionRowDisplayItem] = []
	var filter: HistoryIntentFilter = .all
	/// 既定は歌唱日時の新しい順（`performedAt` 降順）。Repository の取得順に依存せず、表示直前に整列する。
	var sortOrder: HistorySortOrder = .performedAtDescending
	/// 生成直後は「初回ロード中」扱いにして、`.task` 発火前の 1 フレームに Empty State が挟まるのを防ぐ。
	var isLoading: Bool = true
	var isLoadingNextPage: Bool = false
	var loadErrorMessage: String?
	/// 削除失敗時のみ表示。`load()` 成功時にクリアする。
	var deleteErrorMessage: String?
	var hasMorePages: Bool = true

	/// `load()` / `deleteSession()` の非同期完了が交差しても、古い方が `sessions` を上書きしないようにする（V1 は単一カウンタで十分）。
	private var loadGeneration = 0
	private var currentPage = 0
	private let pageSize = 20
	private let prefetchThreshold = 5
	/// 一覧に保持する行の上限（値型スナップショットのみだが、極端なスクロールでメモリが線形増加しないよう抑える）。I-015。
	private let maxDisplayedSessionRows = 500

	init(sessionRepository: any SessionRepositoryProtocol) {
		self.sessionRepository = sessionRepository
	}

	func load() async {
		await loadInitial()
	}

	func loadInitial() async {
		loadGeneration += 1
		let myGeneration = loadGeneration
		let requestedFilter = filter
		isLoading = true
		isLoadingNextPage = false
		currentPage = 0
		hasMorePages = true
		loadErrorMessage = nil
		deleteErrorMessage = nil
		defer {
			if myGeneration == loadGeneration {
				isLoading = false
			}
		}

		do {
			let rows = try await fetchPage(for: requestedFilter, page: 0)
			try Task.checkCancellation()
			guard myGeneration == loadGeneration, requestedFilter == filter else { return }
			applyInitialPage(rows)
		} catch is CancellationError {
			// キャンセル済み／古い要求: 状態は新しい `load` に任せる
		} catch {
			guard myGeneration == loadGeneration, requestedFilter == filter else { return }
			sessions = []
			loadErrorMessage = "読み込みに失敗しました。もう一度お試しください"
		}
	}

	private func applyInitialPage(_ rows: [SingingSession]) {
		let items = rows.map { HistorySessionRowDisplayItem(mapping: $0) }
		sessions = sortOrder.sorted(items)
		currentPage = rows.isEmpty ? 0 : 1
		hasMorePages = rows.count == pageSize
		enforceDisplayedSessionCap()
	}

	private func appendPage(_ rows: [SingingSession]) {
		guard !rows.isEmpty else {
			hasMorePages = false
			return
		}
		let items = rows.map { HistorySessionRowDisplayItem(mapping: $0) }
		let existingIDs = Set(sessions.map(\.id))
		let merged = sessions + items.filter { !existingIDs.contains($0.id) }
		sessions = sortOrder.sorted(merged)
		currentPage += 1
		hasMorePages = rows.count == pageSize
		enforceDisplayedSessionCap()
	}

	/// 表示用配列が上限を超えたら末尾を捨て、それ以上の追加読み込みを止める（現在のソート順で「下側」を落とす）。
	private func enforceDisplayedSessionCap() {
		guard sessions.count > maxDisplayedSessionRows else { return }
		sessions = Array(sessions.prefix(maxDisplayedSessionRows))
		hasMorePages = false
	}

	private func fetchPage(for filter: HistoryIntentFilter, page: Int) async throws -> [SingingSession] {
		let offset = page * pageSize
		switch filter {
		case .all:
			return try await sessionRepository.fetchAll(limit: pageSize, offset: offset)
		case .intent(let intent):
			return try await sessionRepository.fetchByIntent(intent, limit: pageSize, offset: offset)
		}
	}

	/// `load()` 済みの一覧に対し、並び替えのみをやり直す（再フェッチなし）。
	func applySortToLoadedSessions() {
		guard !sessions.isEmpty else { return }
		sessions = sortOrder.sorted(sessions)
	}

	func loadNextPageIfNeeded(currentItemID: UUID) async {
		guard shouldPrefetch(for: currentItemID) else { return }
		guard !isLoading, !isLoadingNextPage, hasMorePages else { return }
		let myGeneration = loadGeneration
		let requestedFilter = filter
		let nextPage = currentPage
		isLoadingNextPage = true
		defer {
			if myGeneration == loadGeneration {
				isLoadingNextPage = false
			}
		}
		do {
			let rows = try await fetchPage(for: requestedFilter, page: nextPage)
			try Task.checkCancellation()
			guard myGeneration == loadGeneration, requestedFilter == filter else { return }
			loadErrorMessage = nil
			appendPage(rows)
		} catch is CancellationError {
		} catch {
			guard myGeneration == loadGeneration, requestedFilter == filter else { return }
			loadErrorMessage = "追加の読み込みに失敗しました。もう一度お試しください"
		}
	}

	/// 末尾 `prefetchThreshold` 行に該当セルが含まれるときだけ次ページを取りにいく（全件 `firstIndex` より O(1) に近い）。
	private func shouldPrefetch(for itemID: UUID) -> Bool {
		guard !sessions.isEmpty else { return false }
		let startIndex = max(0, sessions.count - prefetchThreshold)
		return sessions[startIndex...].contains(where: { $0.id == itemID })
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
		await load()
	}
}
