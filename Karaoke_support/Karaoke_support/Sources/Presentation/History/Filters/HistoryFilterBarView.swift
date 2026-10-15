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

	private func chip(title: String, systemImage: String?, tag: HistoryIntentFilter) -> some View {
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
			HStack(spacing: 4) {
				// 記録シートの気分ボタンと同じアイコン。選んだときはアイコンだけ気分の色にする
				if let systemImage {
					Image(systemName: systemImage)
						.foregroundStyle(isSelected ? accent : AppColor.foregroundSubtle)
						.accessibilityHidden(true)
				}
				Text(title)
			}
				.font(.subheadline.weight(.semibold))
				// アイコンの分だけ広がるので、標準の文字サイズで 4 つが横幅に収まるよう左右を 14pt から詰める
				.padding(.horizontal, 10)
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
}

#Preview {
	@Previewable @State var selection: HistoryIntentFilter = .intent(.emo)
	return HistoryFilterBarView(selection: $selection)
		.padding()
		.background(AppColor.backgroundGradientEnd)
}
