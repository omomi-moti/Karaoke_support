import SwiftUI

/// 検索タブの上に出す「曲名」「歌手名」の切り替え（ADR 0066）。履歴の「すべて」と同じ無彩色のチップにする。
struct SearchTargetBarView: View {
    @Binding var selection: SearchTarget

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SearchTarget.allCases, id: \.self) { target in
                IntentChipView(
                    title: target.title,
                    systemImage: target.systemImage,
                    accent: AppColor.textPrimary,
                    isSelected: selection == target,
                    glowsWhenSelected: false,
                    selectedBorderColor: AppColor.textPrimary.opacity(0.5),
                    accessibilityLabel: "\(target.title)で探す",
                    action: { selection = target }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    @Previewable @State var selection: SearchTarget = .artist
    return SearchTargetBarView(selection: $selection)
        .padding()
        .background(AppColor.backgroundGradientEnd)
}
