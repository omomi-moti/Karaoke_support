#if DEBUG || BETA
import AuthenticationServices
import SwiftUI

/// 空の画面の「前の iPhone の記録を取り込む」（#195、ADR 0071）。サインインしていなければ、その場で Apple のサインインを出す。
/// 取り込めたら、タブを移らずに画面に記録を読み直してもらう。
struct RestoreFromEmptyStateView: View {
	@State private var viewModel: RestoreFromEmptyStateViewModel
	@Environment(\.authorizationController) private var authorizationController
	@Environment(\.notifyRecordsChanged) private var notifyRecordsChanged

	init(accountRepository: any AccountRepositoryProtocol, backupRepository: any BackupRepositoryProtocol) {
		_viewModel = State(initialValue: RestoreFromEmptyStateViewModel(
			accountRepository: accountRepository,
			backupRepository: backupRepository
		))
	}

	var body: some View {
		VStack(spacing: 8) {
			if viewModel.isAvailable {
				Button {
					Task { await start() }
				} label: {
					HStack(spacing: 8) {
						Text(viewModel.activity == .restoring ? "取り込んでいます…" : SingingEmptyStateCopy.restoreButtonTitle)
						if viewModel.isWorking {
							ProgressView()
						}
					}
				}
				.font(.subheadline)
				.disabled(viewModel.isWorking)
			}
			if let errorMessage = viewModel.errorMessage {
				Text(errorMessage)
					.font(.footnote)
					.foregroundStyle(AppColor.textSecondary)
					.multilineTextAlignment(.center)
			}
		}
		.task { await viewModel.load() }
		.onChange(of: viewModel.restoredSessionCount) {
			if viewModel.restoredSessionCount != nil {
				notifyRecordsChanged()
			}
		}
		.alert(
			"バックアップがあります",
			isPresented: Binding(
				get: { viewModel.restorePrompt != nil },
				set: { if !$0 { viewModel.cancelRestorePrompt() } }
			),
			presenting: viewModel.restorePrompt
		) { _ in
			Button("取り込む") {
				Task { await viewModel.restore() }
			}
			Button("キャンセル", role: .cancel) {
				viewModel.cancelRestorePrompt()
			}
		} message: { prompt in
			Text("サーバーの記録 \(prompt.sessionCount) 件（\(prompt.updatedAt.formatted(date: .abbreviated, time: .shortened))）を、この iPhone に取り込みます。")
		}
	}

	/// サインイン中なら控えを読んで聞く。していなければ、Apple のサインインを出してから聞く。Apple のシートを出せるのは View なので、ここで受け取って ViewModel に渡す。
	private func start() async {
		guard viewModel.needsSignIn else {
			await viewModel.checkRestorable()
			return
		}
		let request = ASAuthorizationAppleIDProvider().createRequest()
		request.requestedScopes = []
		request.nonce = viewModel.beginSignIn()
		do {
			let result = try await authorizationController.performRequest(request)
			guard case .appleID(let credential) = result else {
				viewModel.signInFailed(ASAuthorizationError(.failed))
				return
			}
			await viewModel.signIn(identityToken: credential.identityToken)
		} catch {
			viewModel.signInFailed(error)
		}
	}
}

#Preview("サインインしていない") {
	RestoreFromEmptyStateView(
		accountRepository: PreviewAccountRepository(),
		backupRepository: PreviewBackupRepository()
	)
}

#Preview("サインイン中で控えあり") {
	RestoreFromEmptyStateView(
		accountRepository: PreviewAccountRepository(isSignedIn: true),
		backupRepository: PreviewBackupRepository(restorable: BackupRestorableSummary(sessionCount: 42, updatedAt: Date()))
	)
}
#endif
