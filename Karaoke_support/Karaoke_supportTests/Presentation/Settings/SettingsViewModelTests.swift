import Foundation
import Testing

@testable import Karaoke_support

@MainActor
private final class StubInsightRepository: InsightRepositoryProtocol {
	var result: Result<RecordSourceCounts, any Error>

	init(result: Result<RecordSourceCounts, any Error>) {
		self.result = result
	}

	func fetchTimeMachineRanking() async throws -> [InsightTrackCountRanking] { [] }

	func fetchMyAnthemRankings(period: InsightPeriod) async throws -> [MyAnthemRanking] { [] }

	func fetchRecordSourceCounts() async throws -> RecordSourceCounts {
		try result.get()
	}
}

private struct StubError: Error {}

@Suite("SettingsViewModel 提案から記録した数")
@MainActor
struct SettingsViewModelTests {

	@Test("読み込むと、提案から記録した数が入る")
	func loadsCounts() async {
		let vm = SettingsViewModel(
			insightRepository: StubInsightRepository(result: .success(RecordSourceCounts(suggestion: 3, recorded: 10)))
		)

		await vm.load()

		#expect(vm.recordSourceCounts == RecordSourceCounts(suggestion: 3, recorded: 10))
		#expect(vm.loadErrorMessage == nil)
	}

	@Test("読み込めなかったら、数を消してエラーを出す")
	func showsErrorWhenLoadFails() async {
		let repository = StubInsightRepository(result: .success(RecordSourceCounts(suggestion: 3, recorded: 10)))
		let vm = SettingsViewModel(insightRepository: repository)
		await vm.load()

		repository.result = .failure(StubError())
		await vm.load()

		#expect(vm.recordSourceCounts == nil)
		#expect(vm.loadErrorMessage != nil)
	}

	@Test("再試行で読み込めたら、エラーを消す")
	func clearsErrorAfterRetry() async {
		let repository = StubInsightRepository(result: .failure(StubError()))
		let vm = SettingsViewModel(insightRepository: repository)
		await vm.load()

		repository.result = .success(RecordSourceCounts(suggestion: 1, recorded: 2))
		await vm.load()

		#expect(vm.recordSourceCounts == RecordSourceCounts(suggestion: 1, recorded: 2))
		#expect(vm.loadErrorMessage == nil)
	}
}
