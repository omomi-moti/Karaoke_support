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
		// 選んだチップの光が ScrollView の枠で上下に切れて四角く見えるため、枠の外にも描けるようにする
		.scrollClipDisabled()
	}

	private func chip(title: String, tag: HistoryIntentFilter) -> some View {
		let isSelected = selection == tag
		// 気分のチップは記録シートの気分ボタンと同じ色で光らせる。「すべて」は気分の色と混ざらないよう無彩色にする
		let accent: Color = switch tag {
		case .all: AppColor.textPrimary
		case .intent(let intent): IntentPalette.accent(intent)
		}
		let glowsWhenSelected = tag != .all
		// 「すべて」の枠は、ライトモードで黒い太線にならないよう半透明にする
		let borderColor = tag == .all ? accent.opacity(0.5) : accent

		return Button {
			selection = tag
		} label: {
			Text(title)
				.font(.subheadline.weight(.semibold))
				.padding(.horizontal, 14)
				.padding(.vertical, 8)
				.background(
					Capsule()
						.fill(isSelected ? accent.opacity(0.2) : AppColor.filterChipUnselectedBackground)
				)
				.overlay(
					// 選択の切り替えでチップの大きさが変わらないよう、枠は常に内側に描いて色だけ変える
					Capsule()
						.strokeBorder(isSelected ? borderColor : Color.clear, lineWidth: 1.5)
				)
				.foregroundStyle(isSelected ? AppColor.textPrimary : AppColor.foregroundSubtle)
				.shadow(color: isSelected && glowsWhenSelected ? accent.opacity(0.6) : .clear, radius: 6)
		}
		.buttonStyle(.plain)
		.accessibilityLabel("フィルター \(title)")
		.accessibilityAddTraits(isSelected ? .isSelected : [])
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
	@Previewable @State var selection: HistoryIntentFilter = .intent(.emo)
	return HistoryFilterBarView(selection: $selection)
		.padding()
		.background(AppColor.backgroundGradientEnd)
}
