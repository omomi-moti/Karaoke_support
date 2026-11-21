#if DEBUG || BETA
import SwiftUI

/// 同意の画面をシートで出すときの入れ物（#197、ADR 0072）。空の画面で取り込んだあと、`RootView` のシートから出す。
/// オンにした結果（送れなかった理由など）は、設定のバックアップの欄に出る。
struct BackupConsentSheetView: View {
	@State private var viewModel: BackupSectionViewModel
	@Environment(\.dismiss) private var dismiss

	init(backupRepository: any BackupRepositoryProtocol) {
		_viewModel = State(initialValue: BackupSectionViewModel(backupRepository: backupRepository))
	}

	var body: some View {
		NavigationStack {
			BackupConsentView(signIn: nil) {
				Task { await viewModel.enable() }
			}
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("キャンセル") {
						dismiss()
					}
				}
			}
		}
	}
}

#Preview {
	BackupConsentSheetView(backupRepository: PreviewBackupRepository())
}
#endif
