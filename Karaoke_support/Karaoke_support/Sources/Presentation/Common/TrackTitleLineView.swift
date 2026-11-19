import SwiftUI

/// 曲名と、その横に薄い色の歌手名。横に並べて入らないとき（長い曲名・大きい文字）は、歌手名を下の行に回す。
/// 歌手名のない曲は曲名だけを出す。
struct TrackTitleLineView: View {
	let title: String
	let artistName: String?
	var titleFont: Font = .body.weight(.semibold)
	var artistFont: Font = .subheadline
	/// 下の行に回したときの曲名の行数。`nil` なら折り返して全部出す。
	var titleLineLimit: Int? = 1

	var body: some View {
		if let artistName {
			ViewThatFits(in: .horizontal) {
				HStack(alignment: .firstTextBaseline, spacing: 8) {
					titleText.lineLimit(1)
					artistText(artistName)
				}
				VStack(alignment: .leading, spacing: 2) {
					titleText.lineLimit(titleLineLimit)
					artistText(artistName)
				}
			}
		} else {
			titleText.lineLimit(titleLineLimit)
		}
	}

	private var titleText: some View {
		Text(title)
			.font(titleFont)
			.foregroundStyle(AppColor.textPrimary)
			.multilineTextAlignment(.leading)
	}

	private func artistText(_ artistName: String) -> some View {
		Text(artistName)
			.font(artistFont)
			.foregroundStyle(AppColor.textSecondary)
			.lineLimit(1)
	}
}

#Preview {
	VStack(alignment: .leading, spacing: 16) {
		TrackTitleLineView(title: "Lemon", artistName: "米津玄師")
		TrackTitleLineView(title: "とても長い曲名がここに入って横に並ばないときの例", artistName: "米津玄師", titleLineLimit: nil)
		TrackTitleLineView(title: "歌手名のない曲", artistName: nil)
	}
	.padding()
}
