#if DEBUG || BETA
import AuthenticationServices
import Foundation
import Testing

@testable import Karaoke_support

@MainActor
private final class StubAccountRepository: AccountRepositoryProtocol {
	var isSignedIn = false
	var signInError: Error?
	private(set) var signInCalls: [(identityToken: String, rawNonce: String)] = []

	func signInWithApple(identityToken: String, rawNonce: String) async throws {
		signInCalls.append((identityToken, rawNonce))
		if let signInError { throw signInError }
		isSignedIn = true
	}

	func fetchMe() async throws -> Account {
		Account(id: "7d9f0c4e-1111-2222-3333-444455556666", createdAt: Date(timeIntervalSince1970: 0))
	}

	func signOut() async throws {
		isSignedIn = false
	}

	func deleteAccount(identityToken: String, authorizationCode: String, rawNonce: String) async throws {
		isSignedIn = false
	}
}

@MainActor
private final class StubBackupRepository: BackupRepositoryProtocol {
	var status = BackupStatus(isEnabled: false, consentVersion: nil, lastSucceededAt: nil, lastFailure: nil)
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

	func restoreAll() async throws -> Int {
		restoreCallCount += 1
		if let restoreError { throw restoreError }
		return restorable?.sessionCount ?? 0
	}

	func enable() async throws -> BackupOutcome { .uploaded }
	func backUp(trigger: BackupTrigger) async throws -> BackupOutcome { .uploaded }
	func fetchConflict() async throws -> BackupConflict { BackupConflict(serverRevision: 1, serverSessionCount: 0, localSessionCount: 0) }
	func replaceRemote(confirmed conflict: BackupConflict) async throws -> BackupOutcome { .uploaded }
	func fetchRemoteSessionCount() async throws -> Int? { nil }
	func disable() async throws {}
	func retryRemoteDeletion() async throws {}
}

@Suite("RestoreFromEmptyStateViewModel")
@MainActor
struct RestoreFromEmptyStateViewModelTests {

	private let accountRepository = StubAccountRepository()
	private let backupRepository = StubBackupRepository()
	private let summary = BackupRestorableSummary(sessionCount: 42, updatedAt: Date(timeIntervalSince1970: 1_000))

	private func makeViewModel() -> RestoreFromEmptyStateViewModel {
		RestoreFromEmptyStateViewModel(accountRepository: accountRepository, backupRepository: backupRepository)
	}

	private func waitUntil(_ condition: () -> Bool) async throws {
		let deadline = Date().addingTimeInterval(5)
		while !condition() {
			try #require(Date() < deadline)
			await Task.yield()
		}
	}

	@Test("サインインしていなければ、控えを問い合わせずにボタンを出し、押すとサインインから始める")
	func signedOutShowsButtonWithoutQuery() async {
		let vm = makeViewModel()
		await vm.load()

		#expect(vm.isAvailable)
		#expect(vm.needsSignIn)
		#expect(backupRepository.restorableCallCount == 0)
	}

	@Test("サインイン中は、取り込める控えがあるときだけボタンを出す", arguments: [true, false])
	func signedInShowsButtonOnlyWithBackup(hasBackup: Bool) async {
		accountRepository.isSignedIn = true
		backupRepository.restorable = hasBackup ? summary : nil
		let vm = makeViewModel()
		await vm.load()

		#expect(vm.isAvailable == hasBackup)
		#expect(!vm.needsSignIn)
		#expect(vm.restorePrompt == nil)
		#expect(vm.errorMessage == nil)
	}

	@Test("控えがなくて隠したあと、サインインが切れたら、読み直しでボタンを出す")
	func showsButtonAgainAfterSignOut() async {
		accountRepository.isSignedIn = true
		let vm = makeViewModel()
		await vm.load()
		#expect(!vm.isAvailable)

		accountRepository.isSignedIn = false
		await vm.load()

		#expect(vm.isAvailable)
		#expect(vm.needsSignIn)
	}

	@Test("サインイン中に控えがあるかを読めなかったら、押して読み直せるようにボタンを出したままにし、文は出さない")
	func loadFailureKeepsButton() async {
		accountRepository.isSignedIn = true
		backupRepository.restorableError = BackupRestoreFailure.unreachable
		let vm = makeViewModel()
		await vm.load()

		#expect(vm.isAvailable)
		#expect(vm.errorMessage == nil)
	}

	@Test("サインインでは、Apple に渡したハッシュの元の nonce と token を送り、続けて控えを読んで聞く")
	func signInThenPrompts() async throws {
		backupRepository.restorable = summary
		let vm = makeViewModel()

		let hashed = vm.beginSignIn()
		#expect(vm.activity == .signingIn)
		await vm.signIn(identityToken: Data("apple.identity.token".utf8))

		let call = try #require(accountRepository.signInCalls.first)
		#expect(call.identityToken == "apple.identity.token")
		#expect(SignInNonce(raw: call.rawNonce).hashed == hashed)
		#expect(vm.restorePrompt == summary)
		#expect(vm.activity == nil)
	}

	@Test("サインインしたあと控えがなければ、その場で伝えてボタンを隠す")
	func signInWithoutBackup() async {
		let vm = makeViewModel()

		_ = vm.beginSignIn()
		await vm.signIn(identityToken: Data("apple.identity.token".utf8))

		#expect(vm.restorePrompt == nil)
		#expect(vm.errorMessage == "サーバーにバックアップがありませんでした")
		#expect(!vm.isAvailable)
	}

	@Test("Apple の画面でキャンセルしたときは何も出さず、もう一度押せる")
	func signInCanceled() {
		let vm = makeViewModel()

		_ = vm.beginSignIn()
		vm.signInFailed(ASAuthorizationError(.canceled))

		#expect(vm.errorMessage == nil)
		#expect(!vm.isWorking)
		#expect(vm.isAvailable)
	}

	@Test("Apple の画面がキャンセル以外で失敗したら、文を出し、もう一度押せる")
	func signInFailedOtherwise() {
		let vm = makeViewModel()

		_ = vm.beginSignIn()
		vm.signInFailed(ASAuthorizationError(.failed))

		#expect(vm.errorMessage != nil)
		#expect(!vm.isWorking)
		#expect(vm.isAvailable)
	}

	@Test("サーバーでのサインインに失敗したら、文を出し、控えは読まない")
	func serverSignInFailure() async {
		accountRepository.signInError = AccountRepositoryError.unreachable
		let vm = makeViewModel()

		_ = vm.beginSignIn()
		await vm.signIn(identityToken: Data("apple.identity.token".utf8))

		#expect(vm.errorMessage == "サーバーに届きませんでした。通信できる場所でもう一度お試しください")
		#expect(backupRepository.restorableCallCount == 0)
		#expect(!vm.isWorking)
		#expect(vm.isAvailable)
	}

	@Test("nonce を作っていない・token がないときは、サーバーに送らずに文を出す")
	func signInWithoutNonceOrToken() async {
		let vm = makeViewModel()

		await vm.signIn(identityToken: Data("apple.identity.token".utf8))
		#expect(vm.errorMessage != nil)

		_ = vm.beginSignIn()
		await vm.signIn(identityToken: nil)
		#expect(vm.errorMessage != nil)
		#expect(!vm.isWorking)

		#expect(accountRepository.signInCalls.isEmpty)
	}

	@Test("サインイン中に押すと、控えを読んで聞く")
	func checkPromptsWhenSignedIn() async {
		accountRepository.isSignedIn = true
		backupRepository.restorable = summary
		let vm = makeViewModel()

		await vm.checkRestorable()

		#expect(vm.restorePrompt == summary)
	}

	@Test("取り込めたら件数を入れる")
	func restoreSucceeds() async {
		accountRepository.isSignedIn = true
		backupRepository.restorable = summary
		let vm = makeViewModel()
		await vm.checkRestorable()

		await vm.restore()

		#expect(vm.restorePrompt == nil)
		#expect(vm.restoredSessionCount == 42)
		#expect(vm.errorMessage == nil)
		#expect(!vm.isWorking)
	}

	@Test("取り込めたときにオフなら、オンにするかを聞く。聞き終えたらもう聞かない")
	func restoreOffersEnableWhenOff() async {
		accountRepository.isSignedIn = true
		backupRepository.restorable = summary
		let vm = makeViewModel()

		await vm.restore()
		#expect(vm.isOfferingEnable)

		vm.endEnableOffer()
		#expect(!vm.isOfferingEnable)
	}

	@Test("取り込めても、もうオンなら聞かない")
	func restoreDoesNotOfferEnableWhenOn() async {
		accountRepository.isSignedIn = true
		backupRepository.status = BackupStatus(isEnabled: true, consentVersion: BackupStatus.currentConsentVersion, lastSucceededAt: nil, lastFailure: nil)
		backupRepository.restorable = summary
		let vm = makeViewModel()

		await vm.restore()

		#expect(vm.restoredSessionCount == 42)
		#expect(!vm.isOfferingEnable)
	}

	@Test("取り込めなかったら、オンにするかを聞かない")
	func restoreFailureDoesNotOfferEnable() async {
		accountRepository.isSignedIn = true
		backupRepository.restorable = summary
		backupRepository.restoreError = BackupRestoreFailure.unreachable
		let vm = makeViewModel()

		await vm.restore()

		#expect(!vm.isOfferingEnable)
	}

	@Test("聞いた alert でキャンセルしたら、取り込まない")
	func cancelPrompt() async {
		accountRepository.isSignedIn = true
		backupRepository.restorable = summary
		let vm = makeViewModel()
		await vm.checkRestorable()

		vm.cancelRestorePrompt()

		#expect(vm.restorePrompt == nil)
		#expect(backupRepository.restoreCallCount == 0)
		#expect(vm.isAvailable)
	}

	@Test("取り込めなかったら理由を出し、もう一度押せるようにする", arguments: [
		BackupRestoreFailure.unreachable, .server, .signInRequired, .unsupportedVersion, .invalidContents, .localStoreFailed,
	])
	func restoreFailureKeepsButton(failure: BackupRestoreFailure) async {
		accountRepository.isSignedIn = true
		backupRepository.restorable = summary
		backupRepository.restoreError = failure
		let vm = makeViewModel()

		await vm.restore()

		#expect(vm.errorMessage != nil)
		#expect(vm.restoredSessionCount == nil)
		#expect(vm.isAvailable)
		#expect(!vm.isWorking)
	}

	@Test("控えがなくなっていた・端末にもう記録があるときは、理由を出してボタンを隠す", arguments: [
		BackupRestoreFailure.notFound, .localNotEmpty,
	])
	func restoreFailureHidesButton(failure: BackupRestoreFailure) async {
		accountRepository.isSignedIn = true
		backupRepository.restoreError = failure
		let vm = makeViewModel()

		await vm.restore()

		#expect(vm.errorMessage != nil)
		#expect(!vm.isAvailable)
	}

	@Test("前の失敗の文は、次の操作を始めたら消す")
	func errorClearsOnNextAction() async {
		accountRepository.isSignedIn = true
		backupRepository.restorable = summary
		backupRepository.restoreError = BackupRestoreFailure.unreachable
		let vm = makeViewModel()
		await vm.restore()
		#expect(vm.errorMessage != nil)

		backupRepository.restoreError = nil
		await vm.checkRestorable()

		#expect(vm.errorMessage == nil)
		#expect(vm.restorePrompt == summary)
	}

	@Test("最初の読み込みの途中で押しても、重ねて問い合わせない")
	func doesNotOverlapWithLoad() async throws {
		accountRepository.isSignedIn = true
		backupRepository.restorable = summary
		backupRepository.holdsNextRestorable = true
		let vm = makeViewModel()

		let loading = Task { await vm.load() }
		try await waitUntil { backupRepository.isHoldingRestorable }
		await vm.checkRestorable()
		await vm.restore()
		backupRepository.resumeHeldRestorable()
		await loading.value

		#expect(backupRepository.restorableCallCount == 1)
		#expect(backupRepository.restoreCallCount == 0)
		#expect(vm.restorePrompt == nil)
		#expect(!vm.isWorking)
	}
}
#endif
