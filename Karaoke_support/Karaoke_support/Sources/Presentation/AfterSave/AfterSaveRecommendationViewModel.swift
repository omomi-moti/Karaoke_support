import Foundation
import Observation

/// 保存直後のシートの中身を用意する（#115）。
///
/// 候補が 0 件のときはシートを出さないので、シートを出す前に ``prepare(for:)`` で候補を読み込み、出すかどうかを決める。
@MainActor
@Observable
final class AfterSaveRecommendationViewModel {
	/// 保存直後のシートに出す候補の数。
	static let maxRecommendations = 2

	private let trackStatsRepository: any TrackStatsRepositoryProtocol

	/// ``prepare(for:)`` を呼ぶたびに増やす。`await` の後もこの値と一致するときだけ中身を返す。
	@ObservationIgnored private var prepareGeneration: UInt = 0

	/// 今の時刻とカレンダー。テストでは固定する。
	@ObservationIgnored var now: () -> Date = Date.init
	@ObservationIgnored var calendar: Calendar = .current

	init(trackStatsRepository: any TrackStatsRepositoryProtocol) {
		self.trackStatsRepository = trackStatsRepository
	}

	/// 保存した記録に合わせて候補を読み込む。
	///
	/// 「出すかどうか」と「中身」を 1 つの値で返し、出すのに中身がない・前回の中身が残る、という状態を作れないようにしている（ADR 0028 と同じ考え方）。
	/// - Returns: シートの中身。編集して更新したとき・候補が 0 件のとき・読み込みに失敗したとき・後から呼ばれた `prepare` に追い越されたときは `nil`。
	func prepare(for saved: SavedRecording) async -> AfterSaveSheetContent? {
		prepareGeneration += 1
		let attempt = prepareGeneration

		guard saved.isNewRecording else { return nil }

		let stats: [TrackSingingStats]
		do {
			stats = try await trackStatsRepository.fetchTrackSingingStats()
		} catch {
			// 記録はもう保存できているので、提案が出せないだけにする（エラーは出さない）
			return nil
		}
		guard attempt == prepareGeneration else { return nil }

		// Practice で保存したときは、練習中の曲を先に出し、足りなければ歌い切れなかった曲で埋める（#131）。
		// 今保存した曲を勧めないよう、Practice でも今日歌った曲は出さない
		let practice = NextTrackRecommender.practice(from: stats, now: now(), calendar: calendar)
		let found = saved.intent == .practice
			? Array((practice.practicing + practice.unfinished).filter { $0.daysSinceLastSung >= 1 }.prefix(Self.maxRecommendations))
			: NextTrackRecommender.recommend(
				from: stats,
				mood: saved.intent,
				now: now(),
				calendar: calendar,
				limit: Self.maxRecommendations
			)
		guard !found.isEmpty else { return nil }
		return AfterSaveSheetContent(saved: saved, recommendations: found)
	}
}
