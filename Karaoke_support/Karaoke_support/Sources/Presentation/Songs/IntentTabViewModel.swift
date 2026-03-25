import Foundation
import Observation

/// 選曲タブ「インテント」セグメントの状態（I-017）。``InsightRepositoryProtocol`` からランキングを取得する。
@MainActor
@Observable
final class IntentTabViewModel {
	private let insightRepository: any InsightRepositoryProtocol
	private let sessionRepository: any SessionRepositoryProtocol

	/// 歌唱セッションが 1 件以上あるか（0 件時は I-016 Empty State）。
	var hasSingingData: Bool = false
	var isLoading: Bool = false
	var loadErrorMessage: String?

	var timeMachineRanking: [InsightTrackCountRanking] = []
	var myAnthemRankings: [MyAnthemRanking] = []

	/// 暦の「今月」に含まれる歌唱回数。
	var monthSessionCount: Int = 0
	/// 今月の歌唱の平均スコア（今月 0 件なら `nil`）。
	var averageScoreThisMonth: Double?

	init(
		insightRepository: any InsightRepositoryProtocol,
		sessionRepository: any SessionRepositoryProtocol
	) {
		self.insightRepository = insightRepository
		self.sessionRepository = sessionRepository
		// 初回描画からローディング表示（`.task` 実行前の空状態フラッシュ防止）。
		isLoading = true
	}

	func load() async {
		isLoading = true
		loadErrorMessage = nil
		defer { isLoading = false }

		do {
			let firstPage = try await sessionRepository.fetchAll(limit: 1, offset: 0)
			hasSingingData = !firstPage.isEmpty
			guard hasSingingData else {
				timeMachineRanking = []
				myAnthemRankings = []
				monthSessionCount = 0
				averageScoreThisMonth = nil
				return
			}

			async let tm = insightRepository.fetchTimeMachineRanking()
			async let ma = insightRepository.fetchMyAnthemRankings(period: .threeMonths)
			timeMachineRanking = try await tm
			myAnthemRankings = try await ma
			try await computeMonthStats()
		} catch {
			loadErrorMessage = "読み込みに失敗しました。もう一度お試しください"
		}
	}

	private func computeMonthStats() async throws {
		let calendar = Calendar.current
		let now = Date()
		guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
			monthSessionCount = 0
			averageScoreThisMonth = nil
			return
		}

		var countInMonth = 0
		var scoreSum = 0.0
		var scoreCount = 0
		var offset = 0
		let pageSize = 500

		while true {
			let batch = try await sessionRepository.fetchAll(limit: pageSize, offset: offset)
			if batch.isEmpty { break }
			for session in batch {
				if session.performedAt >= monthStart {
					countInMonth += 1
					scoreSum += session.score
					scoreCount += 1
				}
			}
			if batch.count < pageSize { break }
			offset += pageSize
		}

		monthSessionCount = countInMonth
		averageScoreThisMonth = scoreCount > 0 ? scoreSum / Double(scoreCount) : nil
	}
}
