import SwiftUI

/// サポートのページを開く行。問い合わせ先と、よくある質問を載せたページで、どのビルドでもアプリの中から開けるようにする。
struct SupportLinkView: View {
	private static let url = URL(string: "https://omomi-moti.github.io/Karaoke_support/support/")!

	var body: some View {
		Link("サポート", destination: Self.url)
	}
}

#Preview {
	List {
		SupportLinkView()
	}
}
