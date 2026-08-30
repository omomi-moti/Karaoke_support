import Foundation
import Observation

@MainActor
@Observable
final class TrackDetailViewModel {
	/// グラフに描く最大点数。これを超える分は履歴リストにのみ出す。
	static let maxChartPoints = 50

	private let sessionRepository: any SessionRepositoryProtocol
	let trackId: UUID
	let trackTitle: String

	private(set) var points: [TrackScoreTrendPoint] = []
	private(set) var summary: TrackScoreSummary?
	/// 生成直後は「初回ロード中」扱いにして、`.task` 発火前の 1 フレームに空状態が挟まるのを防ぐ。
	private(set) var isLoading = true
	private(set) var loadErrorMessage: String?

	/// `.task` の外（再試行ボタン等）から呼ばれた 2 本目を弾く。
	/// `isLoading` は初期値が `true` のため、これを再入判定に流用すると初回ロードが即 return する。
	private var isLoadInFlight = false

	var chartPoints: [TrackScoreTrendPoint] {
		Array(points.suffix(Self.maxChartPoints))
	}

	var isChartTruncated: Bool {
		points.count > Self.maxChartPoints
	}

	init(
		sessionRepository: any SessionRepositoryProtocol,
		trackId: UUID,
		trackTitle: String
	) {
		self.sessionRepository = sessionRepository
		self.trackId = trackId
		self.trackTitle = trackTitle
	}

	/// 非同期処理はこの 1 本だけで、所有者は `.task`。古い結果の破棄は世代番号ではなくキャンセルで行う。
	func load() async {
		guard !isLoadInFlight else { return }
		isLoadInFlight = true
		defer { isLoadInFlight = false }

		isLoading = true
		loadErrorMessage = nil
		defer {
			if !Task.isCancelled {
				isLoading = false
			}
		}

		do {
			let sessions = try await sessionRepository.fetchSessions(trackId: trackId)
			try Task.checkCancellation()
			let items = sessions.enumerated().map { index, session in
				TrackScoreTrendPoint(order: index + 1, mapping: session)
			}
			points = items
			summary = TrackScoreSummary(points: items)
		} catch is CancellationError {
			return
		} catch {
			guard !Task.isCancelled else { return }
			points = []
			summary = nil
			loadErrorMessage = "読み込みに失敗しました。もう一度お試しください"
		}
	}
}
