import SwiftUI

struct InlineErrorRetryView: View {
	let message: String
	let retryTitle: String
	let onRetry: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text(message)
				.font(.subheadline)

			Button(retryTitle) {
				onRetry()
			}
			.buttonStyle(.borderedProminent)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding()
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
	}
}

#Preview {
	InlineErrorRetryView(
		message: "保存に失敗しました。もう一度お試しください",
		retryTitle: "再試行",
		onRetry: {}
	)
	.padding()
}

