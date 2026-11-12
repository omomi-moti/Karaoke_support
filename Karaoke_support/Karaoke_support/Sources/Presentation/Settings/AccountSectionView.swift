#if DEBUG || BETA
import AuthenticationServices
import SwiftUI

/// 設定のアカウントの欄（#152）。サーバーのつなぎ先があるときだけ出す（ADR 0055）。
struct AccountSectionView: View {
	let viewModel: AccountSectionViewModel
	@Environment(\.colorScheme) private var colorScheme
	@State private var isConfirmingDeletion = false

	var body: some View {
		Section {
			switch viewModel.status {
			case .loading:
				ProgressView()
					.frame(maxWidth: .infinity)
			case .signedOut:
				appleButton(.signIn) { credential in
					Task { await viewModel.signIn(identityToken: credential?.identityToken) }
				}
			case .signedIn(let account):
				Label("サインイン中", systemImage: "checkmark.circle")
				LabeledContent("アカウント ID", value: "\(account.id.prefix(8))…")
				Button("ログアウト", role: .destructive) {
					Task { await viewModel.signOut() }
				}
				Button("アカウントを削除", role: .destructive) {
					isConfirmingDeletion = true
				}
				.confirmationDialog("アカウントを削除しますか？", isPresented: $isConfirmingDeletion, titleVisibility: .visible) {
					Button("削除する", role: .destructive) {
						viewModel.beginDeletion()
					}
				} message: {
					Text("サーバーのアカウントとバックアップを消します。この iPhone の記録は消えません。続けると、確認のためにもう一度 Apple でサインインします。")
				}
			case .confirmingDeletion:
				Text("確認のため、もう一度 Apple でサインインしてください。サインインすると、アカウントを削除します。")
				appleButton(.continue) { credential in
					Task { await viewModel.deleteAccount(identityToken: credential?.identityToken, authorizationCode: credential?.authorizationCode) }
				}
				Button("やめる") {
					viewModel.cancelDeletion()
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

	/// Apple のサインインのボタン。名前とメールアドレスは求めず、ViewModel が作った nonce のハッシュを渡す。
	private func appleButton(_ label: SignInWithAppleButton.Label, onCredential: @escaping (ASAuthorizationAppleIDCredential?) -> Void) -> some View {
		SignInWithAppleButton(label) { request in
			request.requestedScopes = []
			request.nonce = viewModel.makeHashedNonce()
		} onCompletion: { result in
			switch result {
			case .success(let authorization):
				onCredential(authorization.credential as? ASAuthorizationAppleIDCredential)
			case .failure(let error):
				viewModel.signInFailed(error)
			}
		}
		.signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
		.frame(height: 44)
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

#Preview("削除の前の確認") {
	@Previewable @State var viewModel = AccountSectionViewModel(accountRepository: PreviewAccountRepository(isSignedIn: true))
	List {
		AccountSectionView(viewModel: viewModel)
	}
	.task {
		await viewModel.load()
		viewModel.beginDeletion()
	}
}
#endif
