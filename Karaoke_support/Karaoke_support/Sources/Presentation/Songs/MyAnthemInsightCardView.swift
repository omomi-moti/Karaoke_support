import SwiftUI

/// マイアンセム（Intent 別ランキング）への導線カード（I-017）。
struct MyAnthemInsightCardView: View {
	let onTapListen: () -> Void

	var body: some View {
		ZStack(alignment: .bottomTrailing) {
			RoundedRectangle(cornerRadius: 28, style: .continuous)
				.fill(
					LinearGradient(
						colors: [
							IntentTabInsightStyle.myAnthemGradientTop,
							IntentTabInsightStyle.myAnthemGradientBottom,
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)

			VStack(alignment: .leading, spacing: 0) {
				HStack(spacing: 10) {
					intentEmojiCircle("🔥")
					intentEmojiCircle("🌙")
					intentEmojiCircle("🎤")
					Spacer()
				}

				Spacer(minLength: 16)

				Text("感情別マイ・アンセム")
					.font(.title2.weight(.bold))
					.foregroundStyle(.white)
				Text("あなたの今の気分に合わせた曲")
					.font(.subheadline)
					.foregroundStyle(Color.white.opacity(0.88))
					.padding(.top, 4)

				Spacer(minLength: 18)

				HStack(spacing: 6) {
					Image(systemName: "sparkles")
						.font(.caption.weight(.semibold))
						.foregroundStyle(Color.white.opacity(0.75))
					Text("AIが選曲しました")
						.font(.caption)
						.foregroundStyle(Color.white.opacity(0.75))
					Spacer()
					Button(action: onTapListen) {
						HStack(spacing: 6) {
							Text("聴く")
								.font(.subheadline.weight(.semibold))
							Image(systemName: "chevron.right")
								.font(.caption.weight(.semibold))
						}
						.foregroundStyle(.white)
						.padding(.horizontal, 18)
						.padding(.vertical, 12)
						.background(Capsule().fill(Color.white.opacity(0.22)))
					}
					.buttonStyle(.plain)
				}
			}
			.padding(22)
		}
		.frame(height: 220)
	}

	private func intentEmojiCircle(_ emoji: String) -> some View {
		Text(emoji)
			.font(.system(size: 22))
			.frame(width: 44, height: 44)
			.background(
				Circle()
					.fill(Color.white.opacity(0.12))
					.overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
			)
	}
}

#Preview {
	MyAnthemInsightCardView(onTapListen: {})
		.padding()
		.background(IntentTabInsightStyle.pageBackground)
}
