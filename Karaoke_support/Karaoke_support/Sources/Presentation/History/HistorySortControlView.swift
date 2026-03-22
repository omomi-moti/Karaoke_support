import SwiftUI

/// 履歴一覧の並び替え（メニュー形式の Picker）。
struct HistorySortControlView: View {
	@Binding var sortOrder: HistorySortOrder

	var body: some View {
		HStack {
			Text("並び替え")
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(AppColor.textSecondary)
			Spacer(minLength: 8)
			Picker("並び替え", selection: $sortOrder) {
				ForEach(HistorySortOrder.allCases, id: \.self) { order in
					Text(order.pickerLabel).tag(order)
				}
			}
			.pickerStyle(.menu)
			.tint(AppColor.textPrimary)
		}
		.accessibilityElement(children: .combine)
		.accessibilityLabel("並び替え、現在は\(sortOrder.accessibilityDescription)")
	}
}

#Preview {
	HistorySortControlView(sortOrder: .constant(.performedAtDescending))
		.padding()
		.background(AppColor.backgroundGradientEnd)
}
