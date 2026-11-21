#if DEBUG || BETA
import AuthenticationServices
import SwiftUI

/// バックアップをオンにする前の同意の画面（#161、ADR 0058）。「オンにする」を押したことを、今の版の同意とする。
/// サインインしていないときは、ボタンを Apple のサインインにし、サインインできたら続けてオンにする（#197、ADR 0072）。
/// 載せる項目を変えたら、``BackupStatus/currentConsentVersion`` を上げる。
struct BackupConsentView: View {
	/// サインインしていないときに渡す、Apple のサインインの受け渡し。
	struct SignIn {
		/// 新しい nonce を作って持ち、Apple の要求に入れるハッシュを返す。
		let makeHashedNonce: () -> String
		/// Apple から受け取った identity token でサインインし、できたら `true` を返す。
		let complete: (Data?) async -> Bool
		/// Apple のサインインの画面が失敗で閉じたとき。
		let fail: (Error) -> Void
	}

	/// nil のときはサインイン中で、「オンにする」を出す。
	let signIn: SignIn?
	let onEnable: () -> Void
	@Environment(\.dismiss) private var dismiss
	@Environment(\.colorScheme) private var colorScheme
	@State private var isSigningIn = false

	var body: some View {
		List {
			Section("送るもの") {
				Text("曲名・歌手名・気分・点数・歌った日時・もう一度歌いたいか・歌い切ったか・記録した画面")
				Text("あわせて、記録と曲の ID、曲を登録・更新した日時")
			}
			Section("送らないもの") {
				Text("メモ")
			}
			Section("目的") {
				Text("iPhone をなくしたときや、機種を変えたときに記録を戻すため")
			}
			Section("置き場所") {
				Text("開発者が用意したサーバー（東京の Google Cloud Run と、シンガポールの Neon のデータベース）")
			}
			Section("送るタイミングと止め方") {
				Text("オンにした後は、アプリを閉じたときに自動で送ります")
				Text("設定でオフにすると、サーバーのバックアップを消します")
			}
			Section {
				Text("開発中のため、サーバーのデータを消すことがあります")
				PrivacyPolicyLinkView()
			}
			if let signIn {
				Section {
					SignInWithAppleButton(.continue) { request in
						request.requestedScopes = []
						request.nonce = signIn.makeHashedNonce()
						isSigningIn = true
					} onCompletion: { result in
						Task { await finishSignIn(signIn, result: result) }
					}
					.signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
					.frame(height: 44)
					.disabled(isSigningIn)
				} footer: {
					Text("Apple でサインインして、バックアップをオンにします。")
				}
			} else {
				Section {
					Button("オンにする") {
						onEnable()
						dismiss()
					}
					.frame(maxWidth: .infinity)
					.fontWeight(.semibold)
				}
			}
		}
		.scrollContentBackground(.hidden)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.appBackgroundGradient()
		.navigationTitle("バックアップをオンにする")
		.navigationBarTitleDisplayMode(.inline)
	}

	/// サインインできたらオンにして閉じる。失敗したときも閉じて、設定のアカウントの欄に理由を見てもらう。キャンセルしたときはこの画面に残る。
	private func finishSignIn(_ signIn: SignIn, result: Result<ASAuthorization, Error>) async {
		defer { isSigningIn = false }
		switch result {
		case .success(let authorization):
			let credential = authorization.credential as? ASAuthorizationAppleIDCredential
			if await signIn.complete(credential?.identityToken) {
				onEnable()
			}
			dismiss()
		case .failure(let error):
			signIn.fail(error)
			if let authorizationError = error as? ASAuthorizationError, authorizationError.code == .canceled {
				return
			}
			dismiss()
		}
	}
}

#Preview("サインイン中") {
	NavigationStack {
		BackupConsentView(signIn: nil) {}
	}
}

#Preview("サインインしていない") {
	NavigationStack {
		BackupConsentView(
			signIn: BackupConsentView.SignIn(makeHashedNonce: { "" }, complete: { _ in false }, fail: { _ in }),
			onEnable: {}
		)
	}
}
#endif
