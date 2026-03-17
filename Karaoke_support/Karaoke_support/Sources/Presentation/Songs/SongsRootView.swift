import SwiftUI

struct SongsRootView: View {
	private enum Segment: String, CaseIterable, Identifiable {
		case intent = "インテント"
		case spotify = "Spotify"

		var id: String { rawValue }
	}

	@State private var segment: Segment = .intent

	var body: some View {
		VStack(spacing: 16) {
			Picker("選曲タブ", selection: $segment) {
				ForEach(Segment.allCases) { segment in
					Text(segment.rawValue).tag(segment)
				}
			}
			.pickerStyle(.segmented)
			.padding(.horizontal)

			Group {
				switch segment {
				case .intent:
					EmptyPlaceholderView(
						title: "インサイト（準備中）",
						message: "V1では表示の土台のみ用意します。まずは1曲歌ってデータを作りましょう。"
					)
				case .spotify:
					EmptyPlaceholderView(
						title: "Spotify視聴履歴（準備中）",
						message: "V1ではプレースホルダー表示です。"
					)
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.navigationTitle("選曲")
		.navigationBarTitleDisplayMode(.inline)
	}
}

#Preview {
	NavigationStack {
		SongsRootView()
	}
}

