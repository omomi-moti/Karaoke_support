import SwiftUI

/// 設定の中身を出す。
struct SettingsContainerView: View {
	#if DEBUG || BETA
	/// サーバーのつなぎ先がないときは nil で、アカウントの欄を出さない（ADR 0055）。
	@State private var accountViewModel: AccountSectionViewModel?
	/// アカウントの欄がないときは nil。サインインしているときだけ欄を出す。
	@State private var backupViewModel: BackupSectionViewModel?
	@Environment(\.backupStatusTick) private var backupStatusTick

	init(
		accountRepository: (any AccountRepositoryProtocol)? = nil,
		backupRepository: (any BackupRepositoryProtocol)? = nil
	) {
		let accountViewModel = accountRepository.map { AccountSectionViewModel(accountRepository: $0) }
		_accountViewModel = State(initialValue: accountViewModel)
		_backupViewModel = State(initialValue: accountViewModel.flatMap { accountViewModel in
			backupRepository.map { backupRepository in
				BackupSectionViewModel(
					backupRepository: backupRepository,
					isSignedIn: { accountRepository?.isSignedIn ?? false },
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
			if let backupViewModel, case .signedIn = accountViewModel?.status {
				BackupSectionView(viewModel: backupViewModel)
			}
			#endif
			Section {
				#if DEBUG || BETA
				Label("記録はこの iPhone に保存されます", systemImage: "iphone")
				#else
				Label("記録はこの iPhone の中にだけ保存されます", systemImage: "iphone")
				#endif
				PrivacyPolicyLinkView()
			} header: {
				Text("データについて")
			} footer: {
				#if DEBUG || BETA
				Text("バックアップをオンにしたときだけ、メモを除いた記録をサーバーにも送ります。メモは外部に送信されません。アプリを削除すると、この iPhone の記録は消えます。")
				#else
				Text("記録・気分・メモは外部に送信されません。アプリを削除すると、記録も消えます。")
				#endif
			}
			Section {
				SupportLinkView()
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
		#endif
	}
}

#Preview {
	SettingsContainerView()
}

#if DEBUG || BETA
#Preview("アカウントの欄あり") {
	NavigationStack {
		SettingsContainerView(
			accountRepository: PreviewAccountRepository(isSignedIn: true),
			backupRepository: PreviewBackupRepository()
		)
	}
}
#endif
