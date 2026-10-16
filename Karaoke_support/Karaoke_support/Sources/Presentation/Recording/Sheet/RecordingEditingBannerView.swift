import SwiftUI

/// 記録の編集中であることと、どの記録を直しているかを示す帯。新規記録と見分けられるよう、編集のときだけ出す。
struct RecordingEditingBannerView: View {
	/// 編集している記録の、編集を始める前の歌唱日時。日時欄を変えても帯の表示は変えない。
	let originalPerformedAt: Date

	var body: some View {
		Label {
			// 履歴の行と同じ表記にして、どの行を開いたか見比べられるようにする
			Text("\(PerformedAtFormat.dateTime(originalPerformedAt)) の記録を編集中")
		} icon: {
			Image(systemName: "pencil")
		}
		.font(.subheadline.weight(.semibold))
		.foregroundStyle(AppColor.textPrimary)
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.vertical, 12)
		.padding(.horizontal, 16)
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
	}
}

#Preview {
	RecordingEditingBannerView(originalPerformedAt: .now)
		.padding()
		.background(AppColor.backgroundGradientEnd)
}
