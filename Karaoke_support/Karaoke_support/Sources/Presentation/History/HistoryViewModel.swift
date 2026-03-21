import Foundation
import Observation

@MainActor
@Observable
final class HistoryViewModel {
	private let sessionRepository: any SessionRepositoryProtocol

	/// 「すべて」も Intent フィルターも **同一の直近ウィンドウ**（件数上限）で揃える。
	/// Intent 絞り込みは `fetchAll` の結果をメモリ上で `filter`（直近 N 件に該当 Intent が無いと空になる仕様）。
	/// 初回は I-015 前でも一覧を出すための上限（大量データは I-015 でページネーション）。
	static let recentSessionsFetchLimit = 200

	var sessions: [SingingSession] = []
	var filter: HistoryIntentFilter = .all
	var isLoading: Bool = false
	var loadErrorMessage: String?

	init(sessionRepository: any SessionRepositoryProtocol) {
		self.sessionRepository = sessionRepository
	}

	func load() async {
		isLoading = true
		loadErrorMessage = nil
		defer { isLoading = false }

		do {
			let rows = try await sessionRepository.fetchAll(limit: Self.recentSessionsFetchLimit, offset: 0)
			switch filter {
			case .all:
				sessions = rows
			case .intent(let intent):
				sessions = rows.filter { $0.intent == intent }
			}
		} catch {
			sessions = []
			loadErrorMessage = "読み込みに失敗しました。もう一度お試しください"
		}
	}
}
