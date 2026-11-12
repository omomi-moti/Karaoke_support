#if DEBUG || BETA
import AuthenticationServices
import SwiftUI

/// 設定の一番下に置く、ログアウトとアカウントの削除の欄。サインイン中だけ出す。
struct AccountActionsSectionView: View {
	let viewModel: AccountSectionViewModel
	@Environment(\.authorizationController) private var authorizationController
	@State private var isConfirmingDeletion = false

	var body: some View {
		if case .signedIn = viewModel.status {
			Section {
				Button("ログアウト") {
					Task { await viewModel.signOut() }
				}
				Button("アカウントを削除", role: .destructive) {
					isConfirmingDeletion = true
				}
				.alert("アカウントを削除しますか？", isPresented: $isConfirmingDeletion) {
					Button("削除する", role: .destructive) {
						Task { await reauthorizeAndDelete() }
					}
					Button("キャンセル", role: .cancel) {}
				} message: {
					Text("続けると、Apple で本人の確認をしてから削除します。")
				}
			} footer: {
				Text("削除すると、サーバーのアカウントを消します。この iPhone の記録は消えません。")
			}
		}
	}

	/// 削除の前に、もう一度 Apple で確認してもらう（ADR 0057）。Apple のシートを出せるのは View なので、ここで受け取って ViewModel に渡す。
	private func reauthorizeAndDelete() async {
		let request = ASAuthorizationAppleIDProvider().createRequest()
		request.requestedScopes = []
		request.nonce = viewModel.makeHashedNonce()
		do {
			let result = try await authorizationController.performRequest(request)
			guard case .appleID(let credential) = result else {
				viewModel.deletionAuthorizationFailed(ASAuthorizationError(.failed))
				return
			}
			await viewModel.deleteAccount(identityToken: credential.identityToken, authorizationCode: credential.authorizationCode)
		} catch {
			viewModel.deletionAuthorizationFailed(error)
		}
	}
}

#Preview("サインイン中") {
	@Previewable @State var viewModel = AccountSectionViewModel(accountRepository: PreviewAccountRepository(isSignedIn: true))
	List {
		AccountActionsSectionView(viewModel: viewModel)
	}
	.task { await viewModel.load() }
}
#endif
