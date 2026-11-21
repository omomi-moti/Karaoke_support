#if DEBUG || BETA
import SwiftUI

/// 設定のバックアップの欄。サインインしているときだけ出す。
/// 「バックアップ」の行にオンかオフかを出し、オフのときは押すと同意の画面（``BackupConsentView``）へ進む。オンのときはオフにするボタンを出す（ADR 0060・0062）。
/// 端末が空でサーバーに控えがあるときは、取り込みの行を出し、サインインの直後には alert で聞く（ADR 0061・0062）。
struct BackupSectionView: View {
	let viewModel: BackupSectionViewModel
	@Environment(\.notifyRecordsChanged) private var notifyRecordsChanged
	@State private var isConfirmingRestore = false

	var body: some View {
		Section {
			if let restorable = viewModel.restorable {
				restoreRow(restorable)
			}

			if let restoredSessionCount = viewModel.restoredSessionCount {
				Label("\(restoredSessionCount) 件の記録を取り込みました", systemImage: "checkmark.circle")
					.foregroundStyle(.secondary)
			}

			if viewModel.isOn {
				LabeledContent("バックアップ", value: "オン")
			} else {
				NavigationLink {
					BackupConsentView {
						Task { await viewModel.enable() }
					}
				} label: {
					LabeledContent("バックアップ", value: "オフ")
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

			if viewModel.isUpToDate {
				Label("バックアップは最新の状態です", systemImage: "checkmark.circle")
					.foregroundStyle(.secondary)
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
			Text("バックアップ")
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

	private func restoreRow(_ restorable: BackupRestorableSummary) -> some View {
		Button {
			isConfirmingRestore = true
		} label: {
			HStack {
				VStack(alignment: .leading, spacing: 2) {
					Text(viewModel.activity == .restoring ? "取り込んでいます…" : "バックアップから取り込む")
					Text("サーバーに \(summary(of: restorable))")
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
				Spacer()
				if viewModel.activity == .restoring {
					ProgressView()
				}
			}
		}
		.disabled(viewModel.isWorking)
		.alert("バックアップから取り込みますか？", isPresented: $isConfirmingRestore) {
			Button("取り込む", action: restore)
			Button("キャンセル", role: .cancel) {}
		} message: {
			Text("サーバーの\(summary(of: restorable))を、この iPhone に取り込みます。")
		}
		.alert(
			"バックアップがあります",
			isPresented: Binding(
				get: { viewModel.restorePrompt != nil },
				set: { if !$0 { viewModel.cancelRestorePrompt() } }
			),
			presenting: viewModel.restorePrompt
		) { _ in
			Button("取り込む", action: restore)
			Button("キャンセル", role: .cancel) {
				viewModel.cancelRestorePrompt()
			}
		} message: { prompt in
			Text("\(summary(of: prompt))。取り込まない場合も、記録がない間は設定から取り込めます。")
		}
	}

	private func summary(of restorable: BackupRestorableSummary) -> String {
		"記録 \(restorable.sessionCount) 件（\(restorable.updatedAt.formatted(date: .abbreviated, time: .shortened))）"
	}

	private func restore() {
		Task {
			await viewModel.restore()
			if viewModel.restoredSessionCount != nil {
				notifyRecordsChanged()
			}
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

#Preview("取り込める") {
	@Previewable @State var viewModel = BackupSectionViewModel(backupRepository: PreviewBackupRepository(
		restorable: BackupRestorableSummary(sessionCount: 42, updatedAt: Date())
	))
	List {
		BackupSectionView(viewModel: viewModel)
	}
	.task { await viewModel.load() }
}

#Preview("サインインの直後") {
	@Previewable @State var viewModel = BackupSectionViewModel(backupRepository: PreviewBackupRepository(
		restorable: BackupRestorableSummary(sessionCount: 42, updatedAt: Date())
	))
	List {
		BackupSectionView(viewModel: viewModel)
	}
	.task { await viewModel.offerRestoreAfterSignIn() }
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
