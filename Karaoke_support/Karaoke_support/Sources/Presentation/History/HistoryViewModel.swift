import Foundation
import Observation

@MainActor
@Observable
final class HistoryViewModel {
	private let sessionRepository: any SessionRepositoryProtocol

	/// 「すべて」も Intent フィルターも **同一の直近ウィンドウ**（件数上限）で揃える。
	/// Intent 絞り込みは `fetchAll` の結果をメモリ上で `filter`（直近 N 件に該当 Intent が無いと空になる仕様）。
	/// 件数は ``SessionRecentWindow/maxSessionCount`` と ``SessionRepositoryProtocol/fetchByIntent`` に合わせる。
	var sessions: [SingingSession] = []
	var filter: HistoryIntentFilter = .all
	var isLoading: Bool = false
	var loadErrorMessage: String?

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
		defer {
			if myGeneration == loadGeneration {
				isLoading = false
			}
		}

		do {
			let rows = try await sessionRepository.fetchAll(limit: SessionRecentWindow.maxSessionCount, offset: 0)
			try Task.checkCancellation()
			guard myGeneration == loadGeneration, requestedFilter == filter else { return }
			switch requestedFilter {
			case .all:
				sessions = rows
			case .intent(let intent):
				sessions = rows.filter { $0.intent == intent }
			}
		} catch is CancellationError {
			// キャンセル済み／古い要求: 状態は新しい `load` に任せる
		} catch {
			guard myGeneration == loadGeneration, requestedFilter == filter else { return }
			sessions = []
			loadErrorMessage = "読み込みに失敗しました。もう一度お試しください"
		}
	}
}
