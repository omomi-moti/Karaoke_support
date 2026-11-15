#if DEBUG || BETA
import Foundation
import Testing

@testable import Karaoke_support

@MainActor
private final class StubBackupRepository: BackupRepositoryProtocol {
	var status = BackupStatus(isEnabled: false, consentVersion: nil, lastSucceededAt: nil, lastFailure: nil)

	/// 呼ばれたときに、状態をこれに書き換えてから ``error`` を投げる。Repository が最後の失敗を置く動きをまねる。
	var statusAfterCall: BackupStatus?
	var error: Error?
	var conflicts: [BackupConflict] = []
	var conflictError: Error?
	var remoteSessionCount: Int?
	var remoteSessionCountError: Error?
	/// `true` にすると、次の ``fetchConflict()`` を ``resumeHeldConflict()`` まで止めておく。
	var holdsNextConflict = false
	private var heldConflict: CheckedContinuation<Void, Never>?

	private(set) var calls: [String] = []
	private(set) var replacedConflicts: [BackupConflict] = []

	/// `true` にすると、次の enable・backUp・replaceRemote・disable・retryRemoteDeletion を ``resumeHeldCall()`` まで止めておく。
	var holdsNextCall = false
	private var heldCall: CheckedContinuation<Void, Never>?

	var isHoldingCall: Bool { heldCall != nil }

	func resumeHeldCall() {
		heldCall?.resume()
		heldCall = nil
	}

	private func finishCall(_ name: String) async throws {
		calls.append(name)
		if holdsNextCall {
			holdsNextCall = false
			await withCheckedContinuation { heldCall = $0 }
		}
		if let statusAfterCall { status = statusAfterCall }
		if let error { throw error }
	}

	func enable() async throws -> BackupOutcome {
		try await finishCall("enable")
		return .uploaded
	}

	func backUp(trigger: BackupTrigger) async throws -> BackupOutcome {
		try await finishCall("backUp(\(trigger))")
		return .uploaded
	}

	func fetchConflict() async throws -> BackupConflict {
		calls.append("fetchConflict")
		let conflict = conflicts.isEmpty ? nil : conflicts.removeFirst()
		if holdsNextConflict {
			holdsNextConflict = false
			await withCheckedContinuation { heldConflict = $0 }
		}
		if let conflictError { throw conflictError }
		return conflict ?? BackupConflict(serverRevision: 1, serverSessionCount: 0, localSessionCount: 0)
	}

	func resumeHeldConflict() {
		heldConflict?.resume()
		heldConflict = nil
	}

	var isHoldingConflict: Bool { heldConflict != nil }

	func replaceRemote(confirmed conflict: BackupConflict) async throws -> BackupOutcome {
		replacedConflicts.append(conflict)
		try await finishCall("replaceRemote")
		return .uploaded
	}

	func fetchRemoteSessionCount() async throws -> Int? {
		calls.append("fetchRemoteSessionCount")
		if let remoteSessionCountError { throw remoteSessionCountError }
		return remoteSessionCount
	}

	func disable() async throws {
		try await finishCall("disable")
	}

	func retryRemoteDeletion() async throws {
		try await finishCall("retryRemoteDeletion")
	}
}

@Suite("BackupSectionViewModel")
@MainActor
struct BackupSectionViewModelTests {

	private let repository = StubBackupRepository()
	private let succeededAt = Date(timeIntervalSince1970: 1_000)

	private static let off = BackupStatus(isEnabled: false, consentVersion: nil, lastSucceededAt: nil, lastFailure: nil)

	private func on(lastFailure: BackupFailure? = nil) -> BackupStatus {
		BackupStatus(isEnabled: true, consentVersion: BackupStatus.currentConsentVersion, lastSucceededAt: succeededAt, lastFailure: lastFailure)
	}

	private func waitUntil(_ condition: () -> Bool) async throws {
		let deadline = Date().addingTimeInterval(5)
		while !condition() {
			try #require(Date() < deadline)
			await Task.yield()
		}
	}

	@Test("端末の状態をそのまま出す")
	func showsStoredStatus() async {
		repository.status = on(lastFailure: .unreachable)
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.load()

		#expect(viewModel.isOn)
		#expect(viewModel.lastSucceededAt == succeededAt)
		#expect(viewModel.failureMessage == "サーバーに届きませんでした。次にアプリを開いたときに、もう一度送ります")
		#expect(viewModel.conflict == nil)
	}

	@Test("同意がいまの版でなければ、オンでもオフに見せる")
	func outdatedConsentIsShownAsOff() async {
		repository.status = BackupStatus(isEnabled: true, consentVersion: 0, lastSucceededAt: nil, lastFailure: nil)
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.load()

		#expect(!viewModel.isOn)
	}

	@Test("オンにすると、送るのに失敗してもオンのままで、失敗は 1 つだけ出す")
	func enableKeepsOnAndShowsFailureOnce() async {
		repository.statusAfterCall = on(lastFailure: .unreachable)
		repository.error = BackupFailure.unreachable
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.enable()

		#expect(repository.calls == ["enable"])
		#expect(viewModel.isOn)
		#expect(!viewModel.isEnabling)
		#expect(viewModel.errorMessage == nil)
		#expect(viewModel.failureMessage == "サーバーに届きませんでした。次にアプリを開いたときに、もう一度送ります")
	}

	@Test("オンにしている間も、切り替えはオンに見せる")
	func showsOnWhileEnabling() async throws {
		repository.statusAfterCall = on(lastFailure: .needsConfirmation)
		repository.holdsNextConflict = true
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		let task = Task { await viewModel.enable() }
		try await waitUntil { repository.isHoldingConflict }
		#expect(viewModel.isEnabling)
		#expect(viewModel.isOn)

		repository.resumeHeldConflict()
		await task.value
		#expect(!viewModel.isEnabling)
	}

	@Test("今すぐバックアップが成功したら、前の失敗を消す")
	func backUpNowClearsFailure() async {
		repository.status = on(lastFailure: .server)
		repository.statusAfterCall = on()
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.backUpNow()

		#expect(repository.calls == ["backUp(manual)"])
		#expect(viewModel.failureMessage == nil)
	}

	@Test("状態に置かれない失敗は、その場に出し、やり直すと消える")
	func unrecordedFailureIsShownInlineAndClearedOnRetry() async {
		repository.status = on()
		repository.error = BackupFailure.server
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.backUpNow()
		#expect(viewModel.failureMessage == "サーバーで問題が起きました。次にアプリを開いたときに、もう一度送ります")

		repository.error = nil
		await viewModel.backUpNow()
		#expect(viewModel.failureMessage == nil)
	}

	@Test("やり直している間は前の失敗を消さず、終わったときに入れ替える")
	func failureStaysUntilRetryFinishes() async throws {
		repository.status = on()
		repository.error = BackupFailure.server
		let viewModel = BackupSectionViewModel(backupRepository: repository)
		await viewModel.backUpNow()
		let previousMessage = try #require(viewModel.failureMessage)

		repository.error = nil
		repository.holdsNextCall = true
		let retry = Task { await viewModel.backUpNow() }
		try await waitUntil { repository.isHoldingCall }
		#expect(viewModel.activity == .backingUp)
		#expect(viewModel.failureMessage == previousMessage)

		repository.resumeHeldCall()
		await retry.value
		#expect(!viewModel.isWorking)
		#expect(viewModel.failureMessage == nil)
	}

	@Test("確認が要るときは件数を読み、読んだ版のまま置き換える")
	func confirmsAndReplacesWithFetchedConflict() async {
		let conflict = BackupConflict(serverRevision: 7, serverSessionCount: 42, localSessionCount: 38)
		repository.status = on(lastFailure: .needsConfirmation)
		repository.conflicts = [conflict]
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.load()
		#expect(viewModel.conflictMessage == "サーバーの 42 件を、この端末の 38 件で置き換えます")

		repository.statusAfterCall = on()
		await viewModel.confirmReplace()

		#expect(repository.replacedConflicts == [conflict])
		#expect(!repository.calls.contains { $0.hasPrefix("backUp") })
		#expect(viewModel.conflict == nil)
		#expect(viewModel.failureMessage == nil)
	}

	@Test("置き換える間にまた食い違ったら、新しい件数を読み直す")
	func replaceConflictAgainRefetches() async {
		let first = BackupConflict(serverRevision: 7, serverSessionCount: 42, localSessionCount: 38)
		let second = BackupConflict(serverRevision: 8, serverSessionCount: 45, localSessionCount: 38)
		repository.status = on(lastFailure: .needsConfirmation)
		repository.conflicts = [first, second]
		let viewModel = BackupSectionViewModel(backupRepository: repository)
		await viewModel.load()

		repository.error = BackupFailure.needsConfirmation
		await viewModel.confirmReplace()

		#expect(viewModel.conflict == second)
		#expect(viewModel.errorMessage == nil)
	}

	@Test("古い読み込みの件数で、新しい件数を上書きしない")
	func staleConflictDoesNotOverwrite() async throws {
		let stale = BackupConflict(serverRevision: 7, serverSessionCount: 42, localSessionCount: 38)
		let fresh = BackupConflict(serverRevision: 8, serverSessionCount: 45, localSessionCount: 38)
		repository.status = on(lastFailure: .needsConfirmation)
		repository.conflicts = [stale, fresh]
		repository.holdsNextConflict = true
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		let first = Task { await viewModel.load() }
		try await waitUntil { repository.isHoldingConflict }
		await viewModel.load()
		repository.resumeHeldConflict()
		await first.value

		#expect(viewModel.conflict == fresh)
	}

	@Test("オフにする前に、サーバーの件数で確認する", arguments: [
		(Int?.some(42), BackupSectionViewModel.DisableConfirmation.remote(sessionCount: 42)),
		(Int?.none, BackupSectionViewModel.DisableConfirmation.noRemote),
	])
	func prepareDisableShowsRemoteCount(count: Int?, expected: BackupSectionViewModel.DisableConfirmation) async {
		repository.status = on()
		repository.remoteSessionCount = count
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.prepareDisable()

		#expect(viewModel.disableConfirmation == expected)
		#expect(!repository.calls.contains("disable"))
	}

	@Test("件数を読めなくても、オフにする確認は出す")
	func prepareDisableWithoutCount() async {
		repository.status = on()
		repository.remoteSessionCountError = BackupFailure.unreachable
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.prepareDisable()

		#expect(viewModel.disableConfirmation == .unknown)
	}

	@Test("確認をやめたら、オフにしない")
	func cancelDisableKeepsOn() async {
		repository.status = on()
		repository.remoteSessionCount = 3
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.prepareDisable()
		viewModel.cancelDisable()

		#expect(viewModel.disableConfirmation == nil)
		#expect(viewModel.isOn)
		#expect(!repository.calls.contains("disable"))
	}

	@Test("消せなかったら「もう一度消す」を出し、消せたら消す")
	func remoteDeletionFailureCanBeRetried() async {
		repository.status = on()
		repository.statusAfterCall = BackupStatus(isEnabled: false, consentVersion: 1, lastSucceededAt: succeededAt, lastFailure: .remoteDeletionFailed)
		repository.error = BackupFailure.remoteDeletionFailed
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.disable()

		#expect(!viewModel.isOn)
		#expect(viewModel.canRetryRemoteDeletion)
		#expect(viewModel.failureMessage == "サーバーのバックアップを消せませんでした")

		repository.statusAfterCall = Self.off
		repository.error = nil
		await viewModel.retryRemoteDeletion()

		#expect(repository.calls == ["disable", "retryRemoteDeletion"])
		#expect(!viewModel.canRetryRemoteDeletion)
		#expect(viewModel.failureMessage == nil)
	}

	@Test("401 のときは、アカウントの欄に読み直してもらい、失敗は出さない")
	func signInRequiredNotifiesAccountSection() async {
		var signInRequiredCount = 0
		repository.status = on()
		repository.statusAfterCall = Self.off
		repository.error = BackupFailure.signInRequired
		let viewModel = BackupSectionViewModel(backupRepository: repository) { signInRequiredCount += 1 }

		await viewModel.backUpNow()

		#expect(signInRequiredCount == 1)
		#expect(!viewModel.isOn)
		#expect(viewModel.failureMessage == nil)
	}

	@Test("件数を読むときの 401 でも、アカウントの欄に読み直してもらう")
	func signInRequiredWhileFetchingCount() async {
		var signInRequiredCount = 0
		repository.status = on()
		repository.remoteSessionCountError = BackupFailure.signInRequired
		let viewModel = BackupSectionViewModel(backupRepository: repository) { signInRequiredCount += 1 }

		await viewModel.prepareDisable()

		#expect(signInRequiredCount == 1)
		#expect(viewModel.disableConfirmation == nil)
	}
}
#endif
