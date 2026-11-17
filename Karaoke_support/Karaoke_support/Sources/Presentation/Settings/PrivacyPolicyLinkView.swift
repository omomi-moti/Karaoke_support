import SwiftUI

/// プライバシーポリシーを開く行。審査ガイドライン 5.1.1 に沿い、どのビルドでもアプリの中から開けるようにする。
struct PrivacyPolicyLinkView: View {
	private static let url = URL(string: "https://omomi-moti.github.io/Karaoke_support/privacy/")!

	var body: some View {
		Link("プライバシーポリシー", destination: Self.url)
	}
}

#Preview {
	List {
		PrivacyPolicyLinkView()
	}
}
