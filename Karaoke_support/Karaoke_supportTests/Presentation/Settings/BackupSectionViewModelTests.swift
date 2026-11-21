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
	var backUpOutcome: BackupOutcome = .uploaded
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
		return backUpOutcome
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

	var restorable: BackupRestorableSummary?
	var restorableError: Error?
	private(set) var restorableCallCount = 0
	/// `true` にすると、次の ``fetchRestorableBackup()`` を ``resumeHeldRestorable()`` まで止めておく。
	var holdsNextRestorable = false
	private var heldRestorable: CheckedContinuation<Void, Never>?
	var isHoldingRestorable: Bool { heldRestorable != nil }
	var restoreError: Error?
	private(set) var restoreCallCount = 0

	func fetchRestorableBackup() async throws -> BackupRestorableSummary? {
		restorableCallCount += 1
		let restorable = restorable
		if holdsNextRestorable {
			holdsNextRestorable = false
			await withCheckedContinuation { heldRestorable = $0 }
		}
		if let restorableError { throw restorableError }
		return restorable
	}

	func resumeHeldRestorable() {
		heldRestorable?.resume()
		heldRestorable = nil
	}

	/// 取り込めたら、端末が空でなくなったのをまねて ``restorable`` を消す。
	func restoreAll() async throws -> Int {
		restoreCallCount += 1
		if let restoreError { throw restoreError }
		let count = restorable?.sessionCount ?? 0
		restorable = nil
		return count
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

	@Test("今すぐバックアップで送ったときも、前回と同じで送らなかったときも、最新の状態と出す", arguments: [BackupOutcome.uploaded, .unchanged])
	func backUpNowShowsUpToDate(outcome: BackupOutcome) async {
		repository.status = on()
		repository.backUpOutcome = outcome
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.backUpNow()

		#expect(viewModel.isUpToDate)
	}

	@Test("失敗したときと、記録がなくて送らなかったときは、最新の状態と出さない")
	func backUpNowDoesNotShowUpToDateWithoutBackup() async {
		repository.status = on()
		repository.backUpOutcome = .noRecords
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.backUpNow()
		#expect(!viewModel.isUpToDate)

		repository.backUpOutcome = .uploaded
		repository.error = BackupFailure.unreachable
		await viewModel.backUpNow()
		#expect(!viewModel.isUpToDate)
	}

	@Test("最新の状態は、次の操作を始めたときと読み直したときに消す")
	func upToDateIsClearedByNextActionOrReload() async throws {
		repository.status = on()
		let viewModel = BackupSectionViewModel(backupRepository: repository)
		await viewModel.backUpNow()
		#expect(viewModel.isUpToDate)

		repository.holdsNextCall = true
		let next = Task { await viewModel.backUpNow() }
		try await waitUntil { repository.isHoldingCall }
		#expect(!viewModel.isUpToDate)
		repository.resumeHeldCall()
		await next.value
		#expect(viewModel.isUpToDate)

		await viewModel.load()
		#expect(!viewModel.isUpToDate)
	}

	@Test("件数を読めなかった文は、読み直して読めたら消える")
	func countFailureIsClearedByReload() async {
		repository.status = on(lastFailure: .needsConfirmation)
		repository.conflictError = BackupFailure.unreachable
		let viewModel = BackupSectionViewModel(backupRepository: repository)
		await viewModel.load()
		#expect(viewModel.failureMessage == "サーバーのバックアップの件数を読めませんでした。時間をおいてもう一度お試しください")

		repository.conflictError = nil
		await viewModel.load()

		#expect(viewModel.conflict != nil)
		#expect(viewModel.failureMessage == "サーバーのバックアップが、この iPhone が最後に送ったものと違います")
	}

	@Test("古い読み込みが、新しい読み込みの失敗の文を消さない")
	func staleLoadKeepsNewerFailure() async throws {
		repository.status = on(lastFailure: .needsConfirmation)
		repository.holdsNextConflict = true
		let viewModel = BackupSectionViewModel(backupRepository: repository)
		let older = Task { await viewModel.load() }
		try await waitUntil { repository.isHoldingConflict }

		repository.conflictError = BackupFailure.unreachable
		await viewModel.load()
		#expect(viewModel.failureMessage == "サーバーのバックアップの件数を読めませんでした。時間をおいてもう一度お試しください")

		repository.conflictError = nil
		repository.resumeHeldConflict()
		await older.value

		#expect(viewModel.failureMessage == "サーバーのバックアップの件数を読めませんでした。時間をおいてもう一度お試しください")
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

	// MARK: - 取り込み（ADR 0061）

	private let summary = BackupRestorableSummary(sessionCount: 42, updatedAt: Date(timeIntervalSince1970: 2_000))

	@Test("端末が空でサーバーに控えがあれば、取り込みの行を出す。サインインの直後でなければ聞かない")
	func showsRestorableWithoutPrompt() async {
		repository.restorable = summary
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.load()

		#expect(viewModel.restorable == summary)
		#expect(viewModel.restorePrompt == nil)
	}

	@Test("トークンがなければ、取り込める控えを問い合わせない")
	func doesNotQueryRestorableWhenSignedOut() async {
		repository.restorable = summary
		let viewModel = BackupSectionViewModel(backupRepository: repository, isSignedIn: { false })

		await viewModel.load()

		#expect(repository.restorableCallCount == 0)
		#expect(viewModel.restorable == nil)
	}

	@Test("サインインの直後は、取り込める控えがあるときだけ聞く", arguments: [true, false])
	func offersRestoreOnlyWithBackup(hasBackup: Bool) async {
		repository.restorable = hasBackup ? summary : nil
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.offerRestoreAfterSignIn()

		#expect(viewModel.restorePrompt == (hasBackup ? summary : nil))
	}

	@Test("聞くのは 1 回だけで、キャンセルしたら次の読み直しでは聞かない")
	func promptIsOnlyOnce() async {
		repository.restorable = summary
		let viewModel = BackupSectionViewModel(backupRepository: repository)
		await viewModel.offerRestoreAfterSignIn()

		viewModel.cancelRestorePrompt()
		await viewModel.load()

		#expect(viewModel.restorePrompt == nil)
		#expect(viewModel.restorable == summary)
	}

	@Test("サインインの直後に読み込みが重なっても、最後に読み終えた結果で聞く")
	func offerSurvivesOverlappingLoad() async throws {
		repository.restorable = summary
		repository.holdsNextRestorable = true
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		let offer = Task { await viewModel.offerRestoreAfterSignIn() }
		try await waitUntil { repository.isHoldingRestorable }
		await viewModel.load()
		repository.resumeHeldRestorable()
		await offer.value

		#expect(viewModel.restorePrompt == summary)
	}

	@Test("取り込めたら件数を出し、取り込みの行を消す")
	func restoreShowsCount() async {
		repository.restorable = summary
		let viewModel = BackupSectionViewModel(backupRepository: repository)
		await viewModel.offerRestoreAfterSignIn()

		await viewModel.restore()

		#expect(repository.restoreCallCount == 1)
		#expect(viewModel.restoredSessionCount == 42)
		#expect(viewModel.restorable == nil)
		#expect(viewModel.restorePrompt == nil)
		#expect(!viewModel.isWorking)
		#expect(viewModel.failureMessage == nil)
	}

	@Test("取り込めたときにオフなら、オンにするかを聞く。聞き終えたらもう聞かない")
	func restoreOffersEnableWhenOff() async {
		repository.restorable = summary
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.restore()
		#expect(viewModel.isOfferingEnable)

		viewModel.endEnableOffer()
		#expect(!viewModel.isOfferingEnable)
	}

	@Test("取り込めても、もうオンなら聞かない")
	func restoreDoesNotOfferEnableWhenOn() async {
		repository.status = BackupStatus(isEnabled: true, consentVersion: BackupStatus.currentConsentVersion, lastSucceededAt: nil, lastFailure: nil)
		repository.restorable = summary
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.restore()

		#expect(viewModel.restoredSessionCount == 42)
		#expect(!viewModel.isOfferingEnable)
	}

	@Test("取り込めなかったら、オンにするかを聞かない", arguments: [BackupRestoreFailure.unreachable, .signInRequired])
	func restoreFailureDoesNotOfferEnable(failure: BackupRestoreFailure) async {
		repository.restorable = summary
		repository.restoreError = failure
		let viewModel = BackupSectionViewModel(backupRepository: repository)

		await viewModel.restore()

		#expect(!viewModel.isOfferingEnable)
	}

	@Test("取り込めた件数は、次の読み直しで消す")
	func restoredCountIsClearedByReload() async {
		repository.restorable = summary
		let viewModel = BackupSectionViewModel(backupRepository: repository)
		await viewModel.restore()

		await viewModel.load()

		#expect(viewModel.restoredSessionCount == nil)
	}

	@Test("取り込めなかったら理由を出し、行は残してもう一度押せるようにする", arguments: [
		(BackupRestoreFailure.unreachable, "サーバーに届きませんでした。時間をおいてもう一度お試しください"),
		(.server, "サーバーで問題が起きました。時間をおいてもう一度お試しください"),
		(.notFound, "サーバーにバックアップがありませんでした"),
		(.unsupportedVersion, "新しいバージョンのアプリで作ったバックアップです。アプリを更新してください"),
		(.invalidContents, "バックアップの中身を読めなかったため、取り込みませんでした"),
		(.localNotEmpty, "この iPhone にはもう記録があるため、取り込めません"),
		(.localStoreFailed, "この iPhone に保存できませんでした。何も取り込んでいません"),
	])
	func restoreFailureMessage(failure: BackupRestoreFailure, message: String) async {
		repository.restorable = summary
		repository.restoreError = failure
		let viewModel = BackupSectionViewModel(backupRepository: repository)
		await viewModel.load()

		await viewModel.restore()

		#expect(viewModel.failureMessage == message)
		#expect(viewModel.restoredSessionCount == nil)
		#expect(viewModel.restorable == summary)
	}

	@Test("取り込みの 401 では、アカウントの欄に読み直してもらい、失敗は出さない")
	func restoreSignInRequired() async {
		var signInRequiredCount = 0
		repository.restorable = summary
		repository.restoreError = BackupRestoreFailure.signInRequired
		var isSignedIn = true
		let viewModel = BackupSectionViewModel(backupRepository: repository, isSignedIn: { isSignedIn }) {
			signInRequiredCount += 1
			isSignedIn = false
		}

		await viewModel.restore()

		#expect(signInRequiredCount == 1)
		#expect(viewModel.failureMessage == nil)
		#expect(viewModel.restorable == nil)
	}

	@Test("控えがあるかを読めなかったら文を出し、前に読めた行は残す")
	func restorableCheckFailureKeepsRow() async {
		repository.restorable = summary
		let viewModel = BackupSectionViewModel(backupRepository: repository)
		await viewModel.load()

		repository.restorableError = BackupRestoreFailure.unreachable
		await viewModel.load()

		#expect(viewModel.failureMessage == "サーバーのバックアップがあるかを確かめられませんでした。時間をおいてもう一度お試しください")
		#expect(viewModel.restorable == summary)
	}

	@Test("控えがあるかを読むときの 401 では、アカウントの欄に読み直してもらい、聞かない")
	func restorableCheckSignInRequired() async {
		var signInRequiredCount = 0
		repository.restorable = summary
		repository.restorableError = BackupRestoreFailure.signInRequired
		let viewModel = BackupSectionViewModel(backupRepository: repository) { signInRequiredCount += 1 }

		await viewModel.offerRestoreAfterSignIn()

		#expect(signInRequiredCount == 1)
		#expect(viewModel.restorable == nil)
		#expect(viewModel.restorePrompt == nil)
		#expect(viewModel.failureMessage == nil)
	}
}
#endif
