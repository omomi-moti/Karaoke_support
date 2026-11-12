import SwiftUI

/// 設定の中身を出す。
struct SettingsContainerView: View {
	#if DEBUG || BETA
	/// サーバーのつなぎ先がないときは nil で、アカウントの欄を出さない（ADR 0055）。
	@State private var accountViewModel: AccountSectionViewModel?

	init(accountRepository: (any AccountRepositoryProtocol)? = nil) {
		_accountViewModel = State(initialValue: accountRepository.map { AccountSectionViewModel(accountRepository: $0) })
	}
	#endif

	var body: some View {
		List {
			#if DEBUG || BETA
			if let accountViewModel {
				AccountSectionView(viewModel: accountViewModel)
			}
			#endif
			Section {
				Label("記録はこの iPhone の中にだけ保存されます", systemImage: "iphone")
			} header: {
				Text("データについて")
			} footer: {
				Text("記録・気分・メモは外部に送信されません。アプリを削除すると、記録も消えます。")
			}
			#if DEBUG || BETA
			if let accountViewModel {
				AccountActionsSectionView(viewModel: accountViewModel)
			}
			#endif
		}
		.scrollContentBackground(.hidden)
		#if DEBUG || BETA
		.task { await accountViewModel?.load() }
		#endif
	}
}

#Preview {
	SettingsContainerView()
}

#if DEBUG || BETA
#Preview("アカウントの欄あり") {
	SettingsContainerView(accountRepository: PreviewAccountRepository(isSignedIn: true))
}
#endif
