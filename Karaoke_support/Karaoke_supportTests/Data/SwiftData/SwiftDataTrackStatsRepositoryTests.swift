import Foundation
import SwiftData
import Testing

@testable import Karaoke_support

@Suite("SwiftDataTrackStatsRepository.fetchTrackSingingStats()")
@MainActor
struct SwiftDataTrackStatsRepositoryTests {

	private let context: ModelContext
	private let sessionRepository: SwiftDataSessionRepository
	private let repository: SwiftDataTrackStatsRepository

	init() throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: configuration)
		context = ModelContext(container)
		sessionRepository = SwiftDataSessionRepository(modelContext: context)
		repository = SwiftDataTrackStatsRepository(modelContext: context)
	}

	private func makeTrack(named name: String) throws -> Track {
		let track = Track(userEnteredName: name)
		context.insert(track)
		try context.save()
		return track
	}

	private func save(_ track: Track, _ intent: Intent, at interval: TimeInterval, score: Double?, wantAgain: Bool = false, isCompleted: Bool = true) async throws {
		try await sessionRepository.saveNewRecordingSession(
			SingingSession(
				track: track,
				intent: intent,
				performedAt: Date(timeIntervalSince1970: interval),
				score: score,
				wantAgain: wantAgain,
				isCompleted: isCompleted
			)
		)
	}

	@Test("最新の気分と日時は、保存した順ではなく歌唱日時が一番新しい記録で決まる")
	func latestValuesComeFromNewestPerformedAt() async throws {
		let track = try makeTrack(named: "曲")
		try await save(track, .shout, at: 300, score: 80)
		try await save(track, .emo, at: 100, score: 90)  // 後から過去の日時で保存した記録

		let stats = try await repository.fetchTrackSingingStats()
		#expect(stats.count == 1)
		#expect(stats.first?.latestIntent == .shout)
		#expect(stats.first?.lastPerformedAt == Date(timeIntervalSince1970: 300))
	}

	@Test("最高点は点数ありの記録だけで求め、点数ありの記録がなければ nil")
	func bestScoreIgnoresMissingScores() async throws {
		let scored = try makeTrack(named: "点数あり")
		try await save(scored, .emo, at: 100, score: 85.5)
		try await save(scored, .emo, at: 200, score: nil)
		try await save(scored, .emo, at: 300, score: 72)
		let unscored = try makeTrack(named: "点数なし")
		try await save(unscored, .emo, at: 100, score: nil)

		let stats = try await repository.fetchTrackSingingStats()
		let byName = Dictionary(uniqueKeysWithValues: stats.map { ($0.userEnteredName ?? "", $0) })
		#expect(byName["点数あり"]?.bestScore == 85.5)
		#expect(byName["点数あり"]?.sessionCount == 3)
		#expect(byName["点数なし"]?.bestScore == nil)
	}

	@Test("曲ごとに分かれ、記録が 1 件もない曲は含めない")
	func groupsByTrackAndSkipsTracksWithoutSessions() async throws {
		let trackA = try makeTrack(named: "A")
		let trackB = try makeTrack(named: "B")
		_ = try makeTrack(named: "記録なし")
		try await save(trackA, .emo, at: 100, score: 80)
		try await save(trackA, .emo, at: 200, score: 85)
		try await save(trackB, .practice, at: 150, score: nil)

		let stats = try await repository.fetchTrackSingingStats()
		#expect(Set(stats.map(\.trackId)) == [trackA.id, trackB.id])
		#expect(stats.first { $0.trackId == trackA.id }?.sessionCount == 2)
	}

	@Test("履歴の直近ウィンドウより多い記録も全部数える")
	func countsBeyondRecentWindow() async throws {
		let track = try makeTrack(named: "たくさん歌った曲")
		let count = SessionRecentWindow.maxSessionCount + 1
		for index in 0..<count {
			context.insert(
				SingingSession(track: track, intent: .emo, performedAt: Date(timeIntervalSince1970: Double(index)), score: nil)
			)
		}
		try context.save()

		let stats = try await repository.fetchTrackSingingStats()
		#expect(stats.first?.sessionCount == count)
	}

	@Test("最新の記録にハートが付いていれば、latestWantAgain が true")
	func latestWantAgainComesFromNewestRecord() async throws {
		let track = try makeTrack(named: "ハートの曲")
		try await save(track, .emo, at: 100, score: 80)
		try await save(track, .emo, at: 200, score: 85, wantAgain: true)

		let stats = try await repository.fetchTrackSingingStats()
		#expect(stats.first?.latestWantAgain == true)
	}

	@Test("ハート付きの曲をハートなしで歌い直すと、latestWantAgain は false に戻る")
	func singingAgainWithoutHeartClearsIt() async throws {
		let track = try makeTrack(named: "歌い直す曲")
		try await save(track, .emo, at: 100, score: 80, wantAgain: true)
		try await save(track, .emo, at: 200, score: 85)

		let stats = try await repository.fetchTrackSingingStats()
		#expect(stats.first?.latestWantAgain == false)
	}

	@Test("最新の記録で歌い切れなかったら、latestIsCompleted が false")
	func latestIsCompletedComesFromNewestRecord() async throws {
		let track = try makeTrack(named: "歌い切れなかった曲")
		try await save(track, .shout, at: 100, score: 80)
		try await save(track, .shout, at: 200, score: nil, isCompleted: false)

		let stats = try await repository.fetchTrackSingingStats()
		#expect(stats.first?.latestIsCompleted == false)
	}

	@Test("歌い切れなかった曲を、あとで歌い切ると latestIsCompleted は true に戻る")
	func completingLaterRestoresIt() async throws {
		let track = try makeTrack(named: "あとで歌い切る曲")
		try await save(track, .shout, at: 100, score: nil, isCompleted: false)
		try await save(track, .shout, at: 200, score: 85)

		let stats = try await repository.fetchTrackSingingStats()
		#expect(stats.first?.latestIsCompleted == true)
	}
}
