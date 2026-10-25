import Foundation
import Observation

/// 設定タブの状態。提案から記録した数を出す（#120）。
@MainActor
@Observable
final class SettingsViewModel {
	private let insightRepository: any InsightRepositoryProtocol

	/// `load()` 呼び出しごとに増やす。`await` 後もこの値と一致するときだけ状態を書く（タブを行き来したときの古い結果で上書きしない）。
	private var loadGeneration: UInt = 0

	/// 読み込む前と、読み込めなかったときは `nil`。
	private(set) var recordSourceCounts: RecordSourceCounts?
	private(set) var loadErrorMessage: String?

	init(insightRepository: any InsightRepositoryProtocol) {
		self.insightRepository = insightRepository
	}

	func load() async {
		loadGeneration += 1
		let attempt = loadGeneration
		do {
			let counts = try await insightRepository.fetchRecordSourceCounts()
			guard attempt == loadGeneration else { return }
			recordSourceCounts = counts
			loadErrorMessage = nil
		} catch {
			guard attempt == loadGeneration else { return }
			recordSourceCounts = nil
			loadErrorMessage = "記録の数を読み込めませんでした。もう一度お試しください"
		}
	}
}
