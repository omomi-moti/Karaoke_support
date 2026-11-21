import SwiftUI

/// 設定の中身を出す。
struct SettingsContainerView: View {
	#if DEBUG || BETA
	/// サーバーのつなぎ先がないときは nil で、アカウントの欄を出さない（ADR 0055）。
	@State private var accountViewModel: AccountSectionViewModel?
	/// アカウントの欄がないときは nil。サインインしていなくても欄を出す（ADR 0072）。
	@State private var backupViewModel: BackupSectionViewModel?
	@Environment(\.backupStatusTick) private var backupStatusTick
	/// 端末にサインインのトークンがあるか。同意の画面で、サインインから始めるかを決める。
	private let isSignedIn: () -> Bool
	/// 取り込んだあとにオンにすると選んだら `true` にし、同意の画面へ進む。
	@State private var isShowingBackupConsent = false

	init(
		accountRepository: (any AccountRepositoryProtocol)? = nil,
		backupRepository: (any BackupRepositoryProtocol)? = nil
	) {
		let isSignedIn = { accountRepository?.isSignedIn ?? false }
		self.isSignedIn = isSignedIn
		let accountViewModel = accountRepository.map { AccountSectionViewModel(accountRepository: $0) }
		_accountViewModel = State(initialValue: accountViewModel)
		_backupViewModel = State(initialValue: accountViewModel.flatMap { accountViewModel in
			backupRepository.map { backupRepository in
				BackupSectionViewModel(
					backupRepository: backupRepository,
					isSignedIn: isSignedIn,
					onSignInRequired: { Task { await accountViewModel.load() } }
				)
			}
		})
	}
	#endif

	var body: some View {
		List {
			#if DEBUG || BETA
			if let accountViewModel {
				AccountSectionView(viewModel: accountViewModel)
			}
			if let accountViewModel, let backupViewModel {
				BackupSectionView(
					viewModel: backupViewModel,
					consentSignIn: consentSignIn(accountViewModel),
					onAcceptEnableOffer: { isShowingBackupConsent = true }
				)
			}
			#endif
			Section {
				#if DEBUG || BETA
				Label("記録はこの iPhone に保存されます", systemImage: "iphone")
				#else
				Label("記録はこの iPhone の中にだけ保存されます", systemImage: "iphone")
				#endif
			} header: {
				Text("データ")
			} footer: {
				#if DEBUG || BETA
				Text("バックアップをオンにしたときだけ、メモを除いた記録をサーバーにも送ります。メモは外部に送信されません。アプリを削除すると、この iPhone の記録は消えます。")
				#else
				Text("記録・気分・メモは外部に送信されません。アプリを削除すると、記録も消えます。")
				#endif
			}
			Section("このアプリについて") {
				SupportLinkView()
				PrivacyPolicyLinkView()
			}
			#if DEBUG || BETA
			if let accountViewModel {
				AccountActionsSectionView(viewModel: accountViewModel)
			}
			#endif
		}
		.scrollContentBackground(.hidden)
		#if DEBUG || BETA
		.task {
			await accountViewModel?.load()
			await backupViewModel?.load()
		}
		.onChange(of: accountViewModel?.status) {
			Task { await backupViewModel?.load() }
		}
		.onChange(of: accountViewModel?.completedSignInCount) {
			Task { await backupViewModel?.offerRestoreAfterSignIn() }
		}
		.onChange(of: backupStatusTick) {
			accountViewModel?.refreshSignInState()
			Task { await backupViewModel?.load() }
		}
		.navigationDestination(isPresented: $isShowingBackupConsent) {
			if let accountViewModel, let backupViewModel {
				BackupConsentView(signIn: consentSignIn(accountViewModel)) {
					Task { await backupViewModel.enable() }
				}
			}
		}
		#endif
	}

	#if DEBUG || BETA
	/// 端末にトークンがなければ、同意の画面でアカウントの欄と同じサインインを使う。
	/// アカウントの欄の表示ではなくトークンで決める。トークンがあってアカウントを読めなかったときに、サインインし直させないため。
	private func consentSignIn(_ accountViewModel: AccountSectionViewModel) -> BackupConsentView.SignIn? {
		guard !isSignedIn() else { return nil }
		return BackupConsentView.SignIn(
			makeHashedNonce: accountViewModel.makeHashedNonce,
			complete: { await accountViewModel.signIn(identityToken: $0) },
			fail: accountViewModel.signInFailed
		)
	}
	#endif
}

#Preview {
	SettingsContainerView()
}

#if DEBUG || BETA
#Preview("サインインしていない") {
	NavigationStack {
		SettingsContainerView(
			accountRepository: PreviewAccountRepository(),
			backupRepository: PreviewBackupRepository()
		)
	}
}

#Preview("アカウントの欄あり") {
	NavigationStack {
		SettingsContainerView(
			accountRepository: PreviewAccountRepository(isSignedIn: true),
			backupRepository: PreviewBackupRepository()
		)
	}
}
#endif
