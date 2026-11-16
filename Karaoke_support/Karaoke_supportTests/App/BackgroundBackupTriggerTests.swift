#if DEBUG || BETA
import Foundation
import SwiftUI
import Testing
import UIKit

@testable import Karaoke_support

@MainActor
private final class StubBackupRepository: BackupRepositoryProtocol {
	let status = BackupStatus(isEnabled: true, consentVersion: BackupStatus.currentConsentVersion, lastSucceededAt: nil, lastFailure: nil)
	var error: Error?
	private(set) var triggers: [BackupTrigger] = []
	/// `true` にすると、次の ``backUp(trigger:)`` を ``resumeHeldBackUp()`` まで止めておく。
	var holdsNextBackUp = false
	private var heldBackUp: CheckedContinuation<Void, Never>?

	var isHoldingBackUp: Bool { heldBackUp != nil }

	func backUp(trigger: BackupTrigger) async throws -> BackupOutcome {
		triggers.append(trigger)
		if holdsNextBackUp {
			holdsNextBackUp = false
			await withCheckedContinuation { heldBackUp = $0 }
		}
		if let error { throw error }
		return .uploaded
	}

	func resumeHeldBackUp() {
		heldBackUp?.resume()
		heldBackUp = nil
	}

	func enable() async throws -> BackupOutcome { .uploaded }
	func fetchConflict() async throws -> BackupConflict { BackupConflict(serverRevision: nil, serverSessionCount: 0, localSessionCount: 0) }
	func replaceRemote(confirmed conflict: BackupConflict) async throws -> BackupOutcome { .uploaded }
	func fetchRemoteSessionCount() async throws -> Int? { nil }
	func disable() async throws {}
	func retryRemoteDeletion() async throws {}
	func fetchRestorableBackup() async throws -> BackupRestorableSummary? { nil }
	func restoreAll() async throws -> Int { 0 }
}

@Suite("BackgroundBackupTrigger")
@MainActor
struct BackgroundBackupTriggerTests {

	private let repository = StubBackupRepository()
	private let identifier = UIBackgroundTaskIdentifier(rawValue: 7)

	private final class BackgroundTaskRecorder {
		var beginCount = 0
		var endedIdentifiers: [UIBackgroundTaskIdentifier] = []
		var expirationHandler: (@MainActor @Sendable () -> Void)?
	}

	private let recorder = BackgroundTaskRecorder()

	private func makeTrigger(beginsWith result: UIBackgroundTaskIdentifier? = nil) -> BackgroundBackupTrigger {
		let recorder = recorder
		let identifier = result ?? identifier
		return BackgroundBackupTrigger(
			backupRepository: repository,
			beginBackgroundTask: { handler in
				recorder.beginCount += 1
				recorder.expirationHandler = handler
				return identifier
			},
			endBackgroundTask: { recorder.endedIdentifiers.append($0) }
		)
	}

	private func waitUntil(_ condition: () -> Bool) async throws {
		let deadline = Date().addingTimeInterval(5)
		while !condition() {
			try #require(Date() < deadline)
			await Task.yield()
		}
	}

	@Test("裏に回ったら、時間をもらってから送り、送り終えたら 1 回だけ返す")
	func backgroundBacksUpAndEndsTaskOnce() async throws {
		let trigger = makeTrigger()

		trigger.handle(.background)
		#expect(recorder.beginCount == 1)
		try await waitUntil { trigger.completedCount == 1 }

		#expect(repository.triggers == [.background])
		#expect(recorder.endedIdentifiers == [identifier])
	}

	@Test("送るのに失敗しても、時間は返し、送り終えたことは伝える")
	func backgroundFailureStillEndsTask() async throws {
		repository.error = BackupFailure.unreachable
		let trigger = makeTrigger()

		trigger.handle(.background)
		try await waitUntil { trigger.completedCount == 1 }

		#expect(recorder.endedIdentifiers == [identifier])
	}

	@Test("時間切れで返した後に送り終えても、もう一度は返さない")
	func expirationEndsTaskOnlyOnce() async throws {
		repository.holdsNextBackUp = true
		let trigger = makeTrigger()

		trigger.handle(.background)
		try await waitUntil { repository.isHoldingBackUp }
		recorder.expirationHandler?()
		#expect(recorder.endedIdentifiers == [identifier])

		repository.resumeHeldBackUp()
		try await waitUntil { trigger.completedCount == 1 }
		#expect(recorder.endedIdentifiers == [identifier])
	}

	@Test("時間をもらえなかったときは、送るが返さない")
	func invalidTaskIsNotEnded() async throws {
		let trigger = makeTrigger(beginsWith: .invalid)

		trigger.handle(.background)
		try await waitUntil { trigger.completedCount == 1 }

		#expect(repository.triggers == [.background])
		#expect(recorder.endedIdentifiers.isEmpty)
	}

	@Test("前に戻ったら、前に戻ったきっかけで送る")
	func activeBacksUpWithForegroundTrigger() async throws {
		let trigger = makeTrigger()

		trigger.handle(.active)
		try await waitUntil { trigger.completedCount == 1 }

		#expect(repository.triggers == [.foreground])
		#expect(recorder.beginCount == 0)
	}

	@Test("裏に回る途中（inactive）では送らない")
	func inactiveDoesNothing() async {
		let trigger = makeTrigger()

		trigger.handle(.inactive)
		await Task.yield()

		#expect(repository.triggers.isEmpty)
		#expect(recorder.beginCount == 0)
		#expect(trigger.completedCount == 0)
	}
}
#endif
