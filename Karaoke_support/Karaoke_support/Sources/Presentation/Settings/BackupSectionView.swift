#if DEBUG || BETA
import SwiftUI

/// 設定のバックアップの欄。サインインしているときだけ出す。
/// オフのときは同意の画面（``BackupConsentView``）へ進む行を、オンのときはオフにするボタンを出す（ADR 0060）。
struct BackupSectionView: View {
	let viewModel: BackupSectionViewModel

	var body: some View {
		Section {
			if !viewModel.isOn {
				NavigationLink("バックアップをオンにする") {
					BackupConsentView {
						Task { await viewModel.enable() }
					}
				}
				.disabled(viewModel.isWorking)
			}

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
					Button(role: .destructive) {
						Task { await viewModel.confirmReplace() }
					} label: {
						progressLabel("置き換える", while: .replacing)
					}
					.buttonStyle(.borderless)
					.disabled(viewModel.isWorking)
				}
			} else if viewModel.isOn {
				Button {
					Task { await viewModel.backUpNow() }
				} label: {
					progressLabel(
						viewModel.activity == .backingUp ? "バックアップしています…" : "今すぐバックアップ",
						while: .backingUp
					)
				}
				.disabled(viewModel.isWorking)
			}

			if viewModel.isOn {
				Button(role: .destructive) {
					Task { await viewModel.prepareDisable() }
				} label: {
					progressLabel("バックアップをオフにする", while: .disabling)
				}
				.disabled(viewModel.isWorking)
			}

			if viewModel.canRetryRemoteDeletion {
				Button {
					Task { await viewModel.retryRemoteDeletion() }
				} label: {
					progressLabel("もう一度消す", while: .deletingRemote)
				}
				.disabled(viewModel.isWorking)
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

	private func progressLabel(_ title: String, while activity: BackupSectionViewModel.Activity) -> some View {
		HStack {
			Text(title)
			Spacer()
			if viewModel.activity == activity {
				ProgressView()
			}
		}
	}
}

#Preview("オフ") {
	@Previewable @State var viewModel = BackupSectionViewModel(backupRepository: PreviewBackupRepository())
	NavigationStack {
		List {
			BackupSectionView(viewModel: viewModel)
		}
	}
}

#Preview("オン") {
	@Previewable @State var viewModel = BackupSectionViewModel(backupRepository: PreviewBackupRepository(
		status: BackupStatus(isEnabled: true, consentVersion: BackupStatus.currentConsentVersion, lastSucceededAt: Date(), lastFailure: .unreachable)
	))
	List {
		BackupSectionView(viewModel: viewModel)
	}
}

#Preview("確認が要る") {
	@Previewable @State var viewModel = BackupSectionViewModel(backupRepository: PreviewBackupRepository(
		status: BackupStatus(isEnabled: true, consentVersion: BackupStatus.currentConsentVersion, lastSucceededAt: Date(), lastFailure: .needsConfirmation)
	))
	List {
		BackupSectionView(viewModel: viewModel)
	}
	.task { await viewModel.load() }
}

#Preview("消せなかった") {
	@Previewable @State var viewModel = BackupSectionViewModel(backupRepository: PreviewBackupRepository(
		status: BackupStatus(isEnabled: false, consentVersion: BackupStatus.currentConsentVersion, lastSucceededAt: nil, lastFailure: .remoteDeletionFailed)
	))
	List {
		BackupSectionView(viewModel: viewModel)
	}
}
#endif
