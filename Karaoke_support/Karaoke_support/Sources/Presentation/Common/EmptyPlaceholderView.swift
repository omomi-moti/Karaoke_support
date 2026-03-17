import SwiftUI

struct EmptyPlaceholderView: View {
	let title: String
	let message: String

	var body: some View {
		ContentUnavailableView(title, systemImage: "sparkles", description: Text(message))
			.padding()
	}
}

#Preview {
	EmptyPlaceholderView(title: "準備中", message: "この画面はV1ではプレースホルダーです。")
}

