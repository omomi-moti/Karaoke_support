import Foundation

/// 曲ごとの歌唱の集計を取得する Repository のプロトコル（#115）。
/// `@MainActor` の実装はもともと Sendable なので、Sendable を契約に入れて `any` 越しにも安全に共有できるようにする（ADR 0027）。
@MainActor
protocol TrackStatsRepositoryProtocol: Sendable {
	/// 全部の記録を曲ごとにまとめる。記録が 1 件もない曲は含めない。並び順は決めない。
	func fetchTrackSingingStats() async throws -> [TrackSingingStats]
}
