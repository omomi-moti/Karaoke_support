#if DEBUG || BETA
import AuthenticationServices
import Foundation
import Testing

@testable import Karaoke_support

@MainActor
private final class StubAccountRepository: AccountRepositoryProtocol {
	var isSignedIn = false
	var account = Account(id: "7d9f0c4e-1111-2222-3333-444455556666", createdAt: Date(timeIntervalSince1970: 0))
	var fetchError: Error?
	var signInError: Error?
	private(set) var fetchCount = 0
	private(set) var signInCalls: [(identityToken: String, rawNonce: String)] = []
	/// `true` にすると、次の ``fetchMe()`` を ``resumeHeldFetch()`` まで止めておく。
	var holdsNextFetch = false
	private(set) var heldContinuation: CheckedContinuation<Void, Never>?
	/// `true` にすると、次の ``signInWithApple(identityToken:rawNonce:)`` を ``resumeHeldSignIn()`` まで止めておく。
	var holdsNextSignIn = false
	private(set) var heldSignIn: CheckedContinuation<Void, Never>?

	func signInWithApple(identityToken: String, rawNonce: String) async throws {
		signInCalls.append((identityToken, rawNonce))
		if holdsNextSignIn {
			holdsNextSignIn = false
			await withCheckedContinuation { heldSignIn = $0 }
		}
		if let signInError { throw signInError }
		isSignedIn = true
	}

	func resumeHeldSignIn() {
		heldSignIn?.resume()
		heldSignIn = nil
	}

	func fetchMe() async throws -> Account {
		fetchCount += 1
		let account = account
		let error = fetchError
		if holdsNextFetch {
			holdsNextFetch = false
			await withCheckedContinuation { heldContinuation = $0 }
		}
		if let error { throw error }
		return account
	}

	func resumeHeldFetch() {
		heldContinuation?.resume()
		heldContinuation = nil
	}

	var signOutError: Error?
	private(set) var signOutCount = 0

	func signOut() async throws {
		signOutCount += 1
		if let signOutError { throw signOutError }
		isSignedIn = false
	}

	var deleteError: Error?
	private(set) var deleteCalls: [(identityToken: String, authorizationCode: String, rawNonce: String)] = []

	func deleteAccount(identityToken: String, authorizationCode: String, rawNonce: String) async throws {
		deleteCalls.append((identityToken, authorizationCode, rawNonce))
		if let deleteError { throw deleteError }
		isSignedIn = false
	}
}

@Suite("AccountSectionViewModel")
@MainActor
struct AccountSectionViewModelTests {

	private let repository = StubAccountRepository()

	private func makeViewModel() -> AccountSectionViewModel {
		AccountSectionViewModel(accountRepository: repository)
	}

	private func isFailed(_ status: AccountSectionViewModel.Status) -> Bool {
		if case .failed = status { return true }
		return false
	}

	@Test("トークンがなければ、サーバーに問い合わせずにサインインしていないと出す")
	func loadWithoutToken() async {
		let vm = makeViewModel()

		await vm.load()

		#expect(vm.status == .signedOut)
		#expect(repository.fetchCount == 0)
	}

	@Test("トークンがあれば、自分のアカウントを読んで出す")
	func loadWithToken() async {
		repository.isSignedIn = true
		let vm = makeViewModel()

		await vm.load()

		#expect(vm.status == .signedIn(repository.account))
	}

	@Test("サーバーがトークンを受け付けなければ、サインインしていないに戻す")
	func loadUnauthorized() async {
		repository.isSignedIn = true
		repository.fetchError = AccountRepositoryError.unauthorized
		let vm = makeViewModel()

		await vm.load()

		#expect(vm.status == .signedOut)
	}

	@Test("届かなければ失敗を出し、読み直すとアカウントを出す", arguments: [AccountRepositoryError.unreachable, .server])
	func loadFailureCanRetry(error: AccountRepositoryError) async {
		repository.isSignedIn = true
		repository.fetchError = error
		let vm = makeViewModel()

		await vm.load()
		#expect(isFailed(vm.status))

		repository.fetchError = nil
		await vm.load()
		#expect(vm.status == .signedIn(repository.account))
	}

	@Test("サインインでは、Apple に渡したハッシュの元の nonce と token をサーバーに送り、アカウントを出す")
	func signInSendsRawNonce() async throws {
		let vm = makeViewModel()
		await vm.load()

		let hashed = vm.makeHashedNonce()
		await vm.signIn(identityToken: Data("apple.identity.token".utf8))

		let call = try #require(repository.signInCalls.first)
		#expect(call.identityToken == "apple.identity.token")
		#expect(SignInNonce(raw: call.rawNonce).hashed == hashed)
		#expect(vm.status == .signedIn(repository.account))
	}

	@Test("nonce を作っていない・token がないときは、サーバーに送らずに失敗を出す")
	func signInWithoutNonceOrToken() async {
		let vm = makeViewModel()

		await vm.signIn(identityToken: Data("apple.identity.token".utf8))
		#expect(isFailed(vm.status))

		_ = vm.makeHashedNonce()
		await vm.signIn(identityToken: nil)
		#expect(isFailed(vm.status))

		#expect(repository.signInCalls.isEmpty)
	}

	@Test("nonce は 1 回のサインインで使い切る")
	func nonceIsUsedOnce() async {
		let vm = makeViewModel()
		_ = vm.makeHashedNonce()
		await vm.signIn(identityToken: Data("first".utf8))

		await vm.signIn(identityToken: Data("second".utf8))

		#expect(repository.signInCalls.count == 1)
		#expect(isFailed(vm.status))
	}

	@Test("サーバーが Apple のトークンを受け付けなければ、サインインしていないではなく失敗を出す")
	func signInRejected() async {
		repository.signInError = AccountRepositoryError.unauthorized
		let vm = makeViewModel()
		await vm.load()

		_ = vm.makeHashedNonce()
		await vm.signIn(identityToken: Data("apple.identity.token".utf8))

		#expect(isFailed(vm.status))
		#expect(repository.fetchCount == 0)
	}

	@Test("Apple の画面でキャンセルしたときは何も出さない")
	func signInCanceled() async {
		let vm = makeViewModel()
		await vm.load()

		_ = vm.makeHashedNonce()
		vm.signInFailed(ASAuthorizationError(.canceled))

		#expect(vm.status == .signedOut)
	}

	@Test("Apple の画面がキャンセル以外で失敗したら、失敗を出す")
	func signInFailedOtherwise() async {
		let vm = makeViewModel()
		await vm.load()

		vm.signInFailed(ASAuthorizationError(.failed))

		#expect(isFailed(vm.status))
	}

	@Test("サインインの途中で読み込みが走っても、サインインの結果を残す")
	func loadDuringSignInKeepsSignInResult() async {
		repository.holdsNextSignIn = true
		let vm = makeViewModel()
		await vm.load()

		_ = vm.makeHashedNonce()
		let signIn = Task { await vm.signIn(identityToken: Data("apple.identity.token".utf8)) }
		while repository.heldSignIn == nil {
			await Task.yield()
		}
		await vm.load()
		#expect(vm.status == .signedOut)

		repository.resumeHeldSignIn()
		await signIn.value

		#expect(vm.status == .signedIn(repository.account))
	}

	@Test("ログアウトすると、サインインしていないに戻す")
	func signOutReturnsToSignedOut() async {
		repository.isSignedIn = true
		let vm = makeViewModel()
		await vm.load()

		await vm.signOut()

		#expect(repository.signOutCount == 1)
		#expect(vm.status == .signedOut)
	}

	@Test("端末からトークンを消せなければ、失敗を出す")
	func signOutFailure() async {
		repository.isSignedIn = true
		repository.signOutError = AccountRepositoryError.tokenStorage
		let vm = makeViewModel()
		await vm.load()

		await vm.signOut()

		#expect(isFailed(vm.status))
	}

	@Test("画面を離れて読み込みが取り消されたときは、失敗を出さない")
	func cancelledLoadShowsNoFailure() async {
		repository.isSignedIn = true
		repository.fetchError = AccountRepositoryError.unreachable
		repository.holdsNextFetch = true
		let vm = makeViewModel()

		let load = Task { await vm.load() }
		while repository.heldContinuation == nil {
			await Task.yield()
		}
		load.cancel()
		repository.resumeHeldFetch()
		await load.value

		#expect(!isFailed(vm.status))
	}

	private func makeSignedInViewModel() async -> AccountSectionViewModel {
		repository.isSignedIn = true
		let vm = makeViewModel()
		await vm.load()
		return vm
	}

	@Test("削除を始めると確認の状態になり、やめるとサインイン中に戻る")
	func beginAndCancelDeletion() async {
		let vm = await makeSignedInViewModel()

		vm.beginDeletion()
		#expect(vm.status == .confirmingDeletion(repository.account))

		vm.cancelDeletion()
		#expect(vm.status == .signedIn(repository.account))
	}

	@Test("サインインしていないときは、削除を始めない")
	func beginDeletionWhenSignedOut() async {
		let vm = makeViewModel()
		await vm.load()

		vm.beginDeletion()

		#expect(vm.status == .signedOut)
	}

	@Test("削除では、Apple に渡したハッシュの元の nonce と token と認可コードを送り、サインインしていないに戻す")
	func deleteAccountSendsRawNonce() async throws {
		let vm = await makeSignedInViewModel()
		vm.beginDeletion()

		let hashed = vm.makeHashedNonce()
		await vm.deleteAccount(identityToken: Data("apple.identity.token".utf8), authorizationCode: Data("apple.code".utf8))

		let call = try #require(repository.deleteCalls.first)
		#expect(call.identityToken == "apple.identity.token")
		#expect(call.authorizationCode == "apple.code")
		#expect(SignInNonce(raw: call.rawNonce).hashed == hashed)
		#expect(vm.status == .signedOut)
	}

	@Test("nonce を作っていない・token や認可コードがないときは、サーバーに送らずに失敗を出す")
	func deleteAccountWithoutNonceOrValues() async {
		let vm = await makeSignedInViewModel()
		vm.beginDeletion()
		let token = Data("apple.identity.token".utf8)
		let code = Data("apple.code".utf8)

		await vm.deleteAccount(identityToken: token, authorizationCode: code)
		#expect(isFailed(vm.status))

		_ = vm.makeHashedNonce()
		await vm.deleteAccount(identityToken: nil, authorizationCode: code)
		#expect(isFailed(vm.status))

		_ = vm.makeHashedNonce()
		await vm.deleteAccount(identityToken: token, authorizationCode: nil)
		#expect(isFailed(vm.status))

		#expect(repository.deleteCalls.isEmpty)
	}

	@Test("削除に失敗したら、失敗を出し、アカウントは残す", arguments: [
		AccountRepositoryError.appleAccountMismatch, .appleCredentialRejected, .unreachable, .server,
	])
	func deleteAccountFailure(error: AccountRepositoryError) async {
		repository.deleteError = error
		let vm = await makeSignedInViewModel()
		vm.beginDeletion()

		_ = vm.makeHashedNonce()
		await vm.deleteAccount(identityToken: Data("apple.identity.token".utf8), authorizationCode: Data("apple.code".utf8))

		#expect(isFailed(vm.status))
		#expect(repository.isSignedIn)
	}

	@Test("届かない・サーバーの失敗では、アカウントは消えていないと伝える", arguments: [AccountRepositoryError.unreachable, .server])
	func deleteAccountFailureSaysNotDeleted(error: AccountRepositoryError) async {
		repository.deleteError = error
		let vm = await makeSignedInViewModel()
		vm.beginDeletion()

		_ = vm.makeHashedNonce()
		await vm.deleteAccount(identityToken: Data("apple.identity.token".utf8), authorizationCode: Data("apple.code".utf8))

		guard case .failed(let message) = vm.status else {
			Issue.record("失敗を出していない")
			return
		}
		#expect(message.contains("消えていません"))
	}

	@Test("サーバーがトークンを受け付けなければ、サインインしていないに戻す")
	func deleteAccountUnauthorized() async {
		repository.deleteError = AccountRepositoryError.unauthorized
		let vm = await makeSignedInViewModel()
		vm.beginDeletion()

		_ = vm.makeHashedNonce()
		await vm.deleteAccount(identityToken: Data("apple.identity.token".utf8), authorizationCode: Data("apple.code".utf8))

		#expect(vm.status == .signedOut)
	}

	@Test("削除の確認で Apple の画面をキャンセルしたら、確認の状態のままにする")
	func deleteAccountAppleCanceled() async {
		let vm = await makeSignedInViewModel()
		vm.beginDeletion()

		_ = vm.makeHashedNonce()
		vm.signInFailed(ASAuthorizationError(.canceled))

		#expect(vm.status == .confirmingDeletion(repository.account))
	}
}
#endif
