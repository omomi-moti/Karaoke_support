import SwiftUI

/// 記録の編集中であることと、どの記録を直しているかを示す帯。新規記録と見分けられるよう、編集のときだけ出す。
struct RecordingEditingBannerView: View {
	/// 編集している記録の、編集を始める前の歌唱日時。日時欄を変えても帯の表示は変えない。
	let originalPerformedAt: Date

	var body: some View {
		HStack(spacing: 12) {
			// 下の入力カードと同じ見た目だと見出しとして読み流されるので、色付きの丸いアイコンと色付きの帯で別物に見せる。
			// 色は点数・気分のピンクに埋もれないよう、履歴の「編集」スワイプと同じ青にする
			Image(systemName: "pencil")
				.font(.subheadline.weight(.bold))
				.foregroundStyle(.white)
				.frame(width: 32, height: 32)
				.background(AppColor.editAccent, in: Circle())
				.accessibilityHidden(true)

			VStack(alignment: .leading, spacing: 2) {
				Text("編集中")
					.font(.subheadline.weight(.bold))
					.foregroundStyle(AppColor.editAccent)
				// 履歴の行と同じ表記にして、どの行を開いたか見比べられるようにする
				Text("\(PerformedAtFormat.dateTime(originalPerformedAt)) の記録")
					.font(.footnote)
					.foregroundStyle(AppColor.textSecondary)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.vertical, 12)
		.padding(.horizontal, 16)
		.background(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.fill(AppColor.editAccent.opacity(0.15))
		)
		.overlay(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.strokeBorder(AppColor.editAccent.opacity(0.6), lineWidth: 1)
		)
		.accessibilityElement(children: .combine)
	}
}

#Preview {
	RecordingEditingBannerView(originalPerformedAt: .now)
		.padding()
		.background(AppColor.backgroundGradientEnd)
}
