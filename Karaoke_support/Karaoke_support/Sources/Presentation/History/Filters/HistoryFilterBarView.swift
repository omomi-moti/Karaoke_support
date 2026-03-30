import SwiftUI

/// 画面上部の Intent フィルター（チップ横スクロール）。
struct HistoryFilterBarView: View {
	@Binding var selection: HistoryIntentFilter

	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				chip(title: "すべて", tag: .all)
				ForEach(Intent.allCases, id: \.self) { intent in
					chip(title: Self.intentChipTitle(intent), tag: .intent(intent))
				}
			}
			.padding(.horizontal, 4)
		}
	}

	private func chip(title: String, tag: HistoryIntentFilter) -> some View {
		Button {
			selection = tag
		} label: {
			Text(title)
				.font(.subheadline.weight(.semibold))
				.padding(.horizontal, 14)
				.padding(.vertical, 8)
				.background(
					Capsule()
						.fill(selection == tag ? AppColor.filterChipSelectedBackground : AppColor.filterChipUnselectedBackground)
				)
				.foregroundStyle(selection == tag ? AppColor.textPrimary : AppColor.foregroundSubtle)
		}
		.buttonStyle(.plain)
		.accessibilityLabel("フィルター \(title)")
	}

	private static func intentChipTitle(_ intent: Intent) -> String {
		switch intent {
		case .shout: return "Shout"
		case .emo: return "Emo"
		case .practice: return "Practice"
		}
	}
}

#Preview {
	HistoryFilterBarView(selection: .constant(.all))
		.padding()
		.background(AppColor.backgroundGradientEnd)
}
