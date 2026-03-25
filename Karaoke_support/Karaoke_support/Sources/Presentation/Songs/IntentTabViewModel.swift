import Foundation
import Observation

/// 選曲タブ「インテント」セグメントの状態（I-017）。``InsightRepositoryProtocol`` からランキングを取得する。
@MainActor
@Observable
final class IntentTabViewModel {
	private let insightRepository: any InsightRepositoryProtocol
	private let sessionRepository: any SessionRepositoryProtocol

	/// `load()` 呼び出しごとに増加。`await` 後もこの値と一致するときだけ状態を書く（再試行連打のレース回避）。
	private var loadGeneration: UInt = 0

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
		loadGeneration += 1
		let attempt = loadGeneration

		isLoading = true
		loadErrorMessage = nil
		defer {
			if attempt == loadGeneration {
				isLoading = false
			}
		}

		do {
			let firstPage = try await sessionRepository.fetchAll(limit: 1, offset: 0)
			guard attempt == loadGeneration else { return }

			hasSingingData = !firstPage.isEmpty
			guard hasSingingData else {
				guard attempt == loadGeneration else { return }
				timeMachineRanking = []
				myAnthemRankings = []
				monthSessionCount = 0
				averageScoreThisMonth = nil
				return
			}

			async let tm = insightRepository.fetchTimeMachineRanking()
			async let ma = insightRepository.fetchMyAnthemRankings(period: .threeMonths)
			let (tmResult, maResult) = try await (tm, ma)
			guard attempt == loadGeneration else { return }
			timeMachineRanking = tmResult
			myAnthemRankings = maResult
			try await computeMonthStats(attempt: attempt)
		} catch is CancellationError {
			// `.task` のキャンセル（セグメント切替等）。エラー表示は出さない。
			return
		} catch {
			guard attempt == loadGeneration else { return }
			loadErrorMessage = "読み込みに失敗しました。もう一度お試しください"
		}
	}

	private func computeMonthStats(attempt: UInt) async throws {
		let calendar = Calendar.current
		let now = Date()
		guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
			monthSessionCount = 0
			averageScoreThisMonth = nil
			return
		}
		/// 暦の「今月」は `monthStart <= performedAt < nextMonthStart`（翌月以降を含めない）。
		guard let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
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
			guard attempt == loadGeneration else { return }
			let batch = try await sessionRepository.fetchAll(limit: pageSize, offset: offset)
			if batch.isEmpty { break }
			for session in batch {
				let t = session.performedAt
				if t >= monthStart, t < nextMonthStart {
					countInMonth += 1
					scoreSum += session.score
					scoreCount += 1
				}
			}
			if batch.count < pageSize { break }
			offset += pageSize
		}

		guard attempt == loadGeneration else { return }
		monthSessionCount = countInMonth
		averageScoreThisMonth = scoreCount > 0 ? scoreSum / Double(scoreCount) : nil
	}
}
