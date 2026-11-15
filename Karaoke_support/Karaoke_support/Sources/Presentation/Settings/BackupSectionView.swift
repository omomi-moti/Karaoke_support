#if DEBUG || BETA
import SwiftUI

/// 設定のバックアップの欄。サインインしているときだけ出す。
/// オンにするときは同意の画面（``BackupConsentView``）へ進む。進む先は List に付けるので、出すかどうかは親から受け取る。
struct BackupSectionView: View {
	let viewModel: BackupSectionViewModel
	@Binding var isShowingConsent: Bool

	var body: some View {
		Section {
			Toggle("記録をバックアップする", isOn: Binding(
				get: { viewModel.isOn },
				set: { isOn in
					if isOn {
						isShowingConsent = true
					} else {
						Task { await viewModel.prepareDisable() }
					}
				}
			))
			.disabled(viewModel.isWorking)

			if viewModel.isOn || viewModel.lastSucceededAt != nil {
				LabeledContent("最後のバックアップ") {
					if let lastSucceededAt = viewModel.lastSucceededAt {
						Text(lastSucceededAt.formatted(date: .abbreviated, time: .shortened))
					} else {
						Text("まだありません")
					}
				}
			}

			if let failureMessage = viewModel.failureMessage {
				Label(failureMessage, systemImage: "exclamationmark.triangle")
					.foregroundStyle(.secondary)
			}

			if let conflictMessage = viewModel.conflictMessage {
				VStack(alignment: .leading, spacing: 8) {
					Text(conflictMessage)
					Button("置き換える", role: .destructive) {
						Task { await viewModel.confirmReplace() }
					}
					.buttonStyle(.borderless)
					.disabled(viewModel.isWorking)
				}
			} else if viewModel.isOn {
				Button("今すぐバックアップ") {
					Task { await viewModel.backUpNow() }
				}
				.disabled(viewModel.isWorking)
			}

			if viewModel.canRetryRemoteDeletion {
				Button("もう一度消す") {
					Task { await viewModel.retryRemoteDeletion() }
				}
				.disabled(viewModel.isWorking)
			}

			if viewModel.isWorking {
				ProgressView()
					.frame(maxWidth: .infinity)
			}
		} header: {
			Text("バックアップ（開発中）")
		} footer: {
			Text("オンにすると、アプリを閉じたときに、メモを除いた記録をサーバーに送ります。")
		}
		.alert("バックアップをオフにしますか？", isPresented: Binding(
			get: { viewModel.disableConfirmation != nil },
			set: { if !$0 { viewModel.cancelDisable() } }
		)) {
			Button("オフにして消す", role: .destructive) {
				Task { await viewModel.disable() }
			}
			Button("キャンセル", role: .cancel) {
				viewModel.cancelDisable()
			}
		} message: {
			Text(viewModel.disableConfirmationMessage ?? "")
		}
	}
}

#Preview("オフ") {
	@Previewable @State var viewModel = BackupSectionViewModel(backupRepository: PreviewBackupRepository())
	List {
		BackupSectionView(viewModel: viewModel, isShowingConsent: .constant(false))
	}
}

#Preview("オン") {
	@Previewable @State var viewModel = BackupSectionViewModel(backupRepository: PreviewBackupRepository(
		status: BackupStatus(isEnabled: true, consentVersion: BackupStatus.currentConsentVersion, lastSucceededAt: Date(), lastFailure: .unreachable)
	))
	List {
		BackupSectionView(viewModel: viewModel, isShowingConsent: .constant(false))
	}
}

#Preview("確認が要る") {
	@Previewable @State var viewModel = BackupSectionViewModel(backupRepository: PreviewBackupRepository(
		status: BackupStatus(isEnabled: true, consentVersion: BackupStatus.currentConsentVersion, lastSucceededAt: Date(), lastFailure: .needsConfirmation)
	))
	List {
		BackupSectionView(viewModel: viewModel, isShowingConsent: .constant(false))
	}
	.task { await viewModel.load() }
}

#Preview("消せなかった") {
	@Previewable @State var viewModel = BackupSectionViewModel(backupRepository: PreviewBackupRepository(
		status: BackupStatus(isEnabled: false, consentVersion: BackupStatus.currentConsentVersion, lastSucceededAt: nil, lastFailure: .remoteDeletionFailed)
	))
	List {
		BackupSectionView(viewModel: viewModel, isShowingConsent: .constant(false))
	}
}
#endif
