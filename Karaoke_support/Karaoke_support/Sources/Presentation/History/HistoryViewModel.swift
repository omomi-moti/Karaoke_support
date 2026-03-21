import Foundation
import Observation

@MainActor
@Observable
final class HistoryViewModel {
	private let sessionRepository: any SessionRepositoryProtocol

	/// 初回は I-015 前でも一覧を出すための上限（大量データは I-015 でページネーション）。
	private static let fetchLimit = 200

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
			switch filter {
			case .all:
				sessions = try await sessionRepository.fetchAll(limit: Self.fetchLimit, offset: 0)
			case .intent(let intent):
				sessions = try await sessionRepository.fetchByIntent(intent)
			}
		} catch {
			sessions = []
			loadErrorMessage = "読み込みに失敗しました。もう一度お試しください"
		}
	}
}
