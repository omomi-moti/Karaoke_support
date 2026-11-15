#if DEBUG || BETA
import SwiftUI

/// バックアップをオンにする前の同意の画面（#161、ADR 0058）。「オンにする」を押したことを、今の版の同意とする。
/// 載せる項目を変えたら、``BackupStatus/currentConsentVersion`` を上げる。
struct BackupConsentView: View {
	let onEnable: () -> Void

	private static let privacyPolicyURL = URL(string: "https://omomi-moti.github.io/Karaoke_support/privacy/")!

	var body: some View {
		List {
			Section("送るもの") {
				Text("曲名・気分・点数・歌った日時・もう一度歌いたいか・歌い切ったか・記録した画面")
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
				Link("プライバシーポリシー", destination: Self.privacyPolicyURL)
			}
			Section {
				Button("オンにする", action: onEnable)
					.frame(maxWidth: .infinity)
					.fontWeight(.semibold)
			}
		}
		.scrollContentBackground(.hidden)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.appBackgroundGradient()
		.navigationTitle("バックアップをオンにする")
		.navigationBarTitleDisplayMode(.inline)
	}
}

#Preview {
	NavigationStack {
		BackupConsentView {}
	}
}
#endif
