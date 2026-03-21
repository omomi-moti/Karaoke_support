import SwiftUI

struct OfflineBannerView: View {
	let onOpenSettings: () -> Void
	let onRetry: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("ネットワークに接続してください")
				.font(.subheadline.bold())

			Text("オフラインでも記録は作成できますが、一部機能が制限されます。")
				.font(.footnote)
				.foregroundStyle(.secondary)

			HStack(spacing: 12) {
				Button("設定を開く") {
					onOpenSettings()
				}
				.buttonStyle(.bordered)

				Button("リトライ") {
					onRetry()
				}
				.buttonStyle(.borderedProminent)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding()
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
	}
}

#Preview {
	OfflineBannerView(onOpenSettings: {}, onRetry: {})
		.padding()
}

