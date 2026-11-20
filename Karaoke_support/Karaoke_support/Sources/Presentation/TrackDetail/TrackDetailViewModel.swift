import Foundation
import Observation

@MainActor
@Observable
final class TrackDetailViewModel {
	/// グラフに描く最大点数。これを超える分は履歴リストにのみ出す。
	static let maxChartPoints = 50

	private let sessionRepository: any SessionRepositoryProtocol
	private let trackRepository: any TrackRepositoryProtocol
	/// 別の曲とまとめると、まとめた先の曲に変わる。
	private(set) var trackId: UUID
	let trackTitle: String
	/// 歌手名のない曲は `nil`。
	private(set) var trackArtistName: String?

	/// 歌手名を直す欄に入れている文字。
	var artistNameDraft = ""
	/// 直した結果、別の曲と重なったときの、まとめる前の確認。
	private(set) var pendingMerge: TrackMergeCandidate?
	private(set) var artistEditErrorMessage: String?
	private var isSavingArtistName = false

	private(set) var points: [TrackScoreTrendPoint] = []
	private(set) var summary: TrackScoreSummary?
	/// 生成直後は「初回ロード中」扱いにして、`.task` 発火前の 1 フレームに空状態が挟まるのを防ぐ。
	private(set) var isLoading = true
	private(set) var loadErrorMessage: String?
	private(set) var deleteErrorMessage: String?

	/// `.task` の外（再試行ボタン等）から呼ばれた 2 本目を弾く。
	/// `isLoading` は初期値が `true` のため、これを再入判定に流用すると初回ロードが即 return する。
	private var isLoadInFlight = false

	/// グラフに描くのは点数ありの記録だけ。
	private var scoredPoints: [TrackScoreTrendPoint] {
		points.filter { $0.score != nil }
	}

	var chartPoints: [TrackScoreTrendPoint] {
		Array(scoredPoints.suffix(Self.maxChartPoints))
	}

	var isChartTruncated: Bool {
		scoredPoints.count > Self.maxChartPoints
	}

	/// 空白だけの歌手名は保存できない（新しい曲と同じく歌手名は必須。ADR 0011）。
	var canSaveArtistName: Bool {
		!trimmedArtistNameDraft.isEmpty && !isSavingArtistName
	}

	private var trimmedArtistNameDraft: String {
		artistNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	init(
		sessionRepository: any SessionRepositoryProtocol,
		trackRepository: any TrackRepositoryProtocol,
		trackId: UUID,
		trackTitle: String,
		trackArtistName: String? = nil
	) {
		self.sessionRepository = sessionRepository
		self.trackRepository = trackRepository
		self.trackId = trackId
		self.trackTitle = trackTitle
		self.trackArtistName = trackArtistName
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

	/// 記録を消す。先に一覧から外し、DB から消すのに失敗したら元に戻す（#135。履歴の削除と同じ考え方）。
	func deleteSession(id: UUID) async {
		deleteErrorMessage = nil
		let snapshot = points
		points.removeAll { $0.id == id }
		summary = TrackScoreSummary(points: points)
		do {
			try await sessionRepository.deleteRecordingSession(uuid: id)
		} catch {
			points = snapshot
			summary = TrackScoreSummary(points: snapshot)
			deleteErrorMessage = "削除に失敗しました。もう一度お試しください"
		}
	}

	/// 歌手名を直す欄を、今の歌手名で始める。
	func beginArtistEdit() {
		artistNameDraft = trackArtistName ?? ""
		artistEditErrorMessage = nil
	}

	/// 歌手名を直す。別の曲と重なるときは書かずに ``pendingMerge`` を出す。
	/// - Returns: 歌手名を書き換えたら `true`（重なったとき・失敗したときは `false`）
	func saveArtistName() async -> Bool {
		guard canSaveArtistName else { return false }
		isSavingArtistName = true
		defer { isSavingArtistName = false }
		artistEditErrorMessage = nil
		let artistName = trimmedArtistNameDraft

		do {
			switch try await trackRepository.updateArtistName(artistName, trackId: trackId) {
			case .updated(let track):
				let changed = trackArtistName != TrackDisplayTitle.artist(for: track)
				trackArtistName = TrackDisplayTitle.artist(for: track)
				return changed
			case .conflicts(let other):
				pendingMerge = TrackMergeCandidate(
					trackId: other.id,
					artistName: artistName,
					singCount: other.singCount
				)
				return false
			}
		} catch {
			artistEditErrorMessage = "歌手名を直せませんでした。もう一度お試しください"
			return false
		}
	}

	/// まとめる前の確認で「まとめる」を押した。確認の表示が閉じるときに ``pendingMerge`` が消えても動くよう、候補は引数で受け取る。
	/// - Returns: まとめたら `true`
	func merge(into candidate: TrackMergeCandidate) async -> Bool {
		guard !isSavingArtistName else { return false }
		isSavingArtistName = true
		defer { isSavingArtistName = false }
		pendingMerge = nil
		artistEditErrorMessage = nil

		do {
			let merged = try await trackRepository.mergeTrack(trackId, into: candidate.trackId)
			trackId = merged.id
			trackArtistName = TrackDisplayTitle.artist(for: merged)
			return true
		} catch {
			artistEditErrorMessage = "曲をまとめられませんでした。もう一度お試しください"
			return false
		}
	}

	func cancelMerge() {
		pendingMerge = nil
	}
}
