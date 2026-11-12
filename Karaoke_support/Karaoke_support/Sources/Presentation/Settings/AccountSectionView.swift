#if DEBUG || BETA
import AuthenticationServices
import SwiftUI

/// 設定のアカウントの欄（#152）。サーバーのつなぎ先があるときだけ出す（ADR 0055）。
struct AccountSectionView: View {
	let viewModel: AccountSectionViewModel
	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		Section {
			switch viewModel.status {
			case .loading:
				ProgressView()
					.frame(maxWidth: .infinity)
			case .signedOut:
				SignInWithAppleButton(.signIn) { request in
					request.requestedScopes = []
					request.nonce = viewModel.makeHashedNonce()
				} onCompletion: { result in
					switch result {
					case .success(let authorization):
						let credential = authorization.credential as? ASAuthorizationAppleIDCredential
						Task { await viewModel.signIn(identityToken: credential?.identityToken) }
					case .failure(let error):
						viewModel.signInFailed(error)
					}
				}
				.signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
				.frame(height: 44)
			case .signedIn(let account):
				Label("サインイン中", systemImage: "checkmark.circle")
				LabeledContent("アカウント ID", value: "\(account.id.prefix(8))…")
				Button("ログアウト", role: .destructive) {
					Task { await viewModel.signOut() }
				}
			case .failed(let message):
				VStack(alignment: .leading, spacing: 8) {
					Text(message)
					Button("再試行") {
						Task { await viewModel.load() }
					}
					.buttonStyle(.borderless)
				}
			}
		} header: {
			Text("アカウント（開発中）")
		} footer: {
			Text("Apple のアカウントでサインインします。名前とメールアドレスは受け取りません。")
		}
	}
}

#Preview("サインインしていない") {
	@Previewable @State var viewModel = AccountSectionViewModel(accountRepository: PreviewAccountRepository())
	List {
		AccountSectionView(viewModel: viewModel)
	}
	.task { await viewModel.load() }
}

#Preview("サインイン中") {
	@Previewable @State var viewModel = AccountSectionViewModel(accountRepository: PreviewAccountRepository(isSignedIn: true))
	List {
		AccountSectionView(viewModel: viewModel)
	}
	.task { await viewModel.load() }
}
#endif
