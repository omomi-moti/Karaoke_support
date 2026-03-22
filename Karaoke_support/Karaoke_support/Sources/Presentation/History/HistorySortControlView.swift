import SwiftUI

/// 履歴一覧の並び替え（メニュー形式の Picker）。
struct HistorySortControlView: View {
	@Binding var sortOrder: HistorySortOrder

	var body: some View {
		HStack {
			Text("並び替え")
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(AppColor.textSecondary)
				/// 視覚ラベル。VoiceOver は右の `Picker` に集約する（二重読み防止）。
				.accessibilityHidden(true)
			Spacer(minLength: 8)
			/// タイトルは空にし、`accessibilityLabel` / `accessibilityValue` で意味を明示（`children: .combine` は Picker 操作を阻害しうるため使わない）。
			Picker("", selection: $sortOrder) {
				ForEach(HistorySortOrder.allCases, id: \.self) { order in
					Text(order.pickerLabel).tag(order)
				}
			}
			.pickerStyle(.menu)
			.tint(AppColor.textPrimary)
			.accessibilityLabel("並び替え")
			.accessibilityValue(sortOrder.accessibilityDescription)
		}
	}
}

#Preview {
	HistorySortControlView(sortOrder: .constant(.performedAtDescending))
		.padding()
		.background(AppColor.backgroundGradientEnd)
}
