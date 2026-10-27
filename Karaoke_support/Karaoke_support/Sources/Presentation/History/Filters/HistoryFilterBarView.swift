import SwiftUI

/// 画面上部の Intent フィルター（チップ横スクロール）。
struct HistoryFilterBarView: View {
	@Binding var selection: HistoryIntentFilter

	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				chip(title: "すべて", systemImage: nil, tag: .all)
				ForEach(Intent.allCases, id: \.self) { intent in
					chip(title: IntentLabel.title(intent), systemImage: IntentLabel.systemImage(intent), tag: .intent(intent))
				}
			}
			.padding(.horizontal, 4)
		}
		// 選んだチップの光が ScrollView の枠で上下に切れて四角く見えるため、枠の外にも描けるようにする
		.scrollClipDisabled()
	}

	private func chip(title: String, systemImage: String?, tag: HistoryIntentFilter) -> IntentChipView {
		let isSelected = selection == tag
		// 気分のチップは記録シートの気分ボタンと同じ色で光らせる。「すべて」は気分の色と混ざらないよう無彩色にする
		let accent: Color = switch tag {
		case .all: AppColor.textPrimary
		case .intent(let intent): IntentPalette.accent(intent)
		}
		let glowsWhenSelected = tag != .all
		// 「すべて」の枠は、ライトモードで黒い太線にならないよう半透明にする
		let borderColor = tag == .all ? accent.opacity(0.5) : accent

		return IntentChipView(
			title: title,
			systemImage: systemImage,
			accent: accent,
			isSelected: isSelected,
			glowsWhenSelected: glowsWhenSelected,
			selectedBorderColor: borderColor,
			accessibilityLabel: "フィルター \(title)",
			action: { selection = tag }
		)
	}
}

#Preview {
	@Previewable @State var selection: HistoryIntentFilter = .intent(.emo)
	return HistoryFilterBarView(selection: $selection)
		.padding()
		.background(AppColor.backgroundGradientEnd)
}
