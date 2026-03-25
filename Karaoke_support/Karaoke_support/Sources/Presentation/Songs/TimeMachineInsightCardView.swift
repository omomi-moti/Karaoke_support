import SwiftUI

/// タイムマシン（過去1ヶ月ランキング）への導線カード（I-017）。
struct TimeMachineInsightCardView: View {
	let onTapLookBack: () -> Void

	var body: some View {
		ZStack(alignment: .bottomTrailing) {
			RoundedRectangle(cornerRadius: 28, style: .continuous)
				.fill(
					LinearGradient(
						colors: [
							IntentTabInsightStyle.timeMachineGradientTop,
							IntentTabInsightStyle.timeMachineGradientBottom,
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)

			VStack(alignment: .leading, spacing: 0) {
				HStack(alignment: .top) {
					ZStack {
						Circle()
							.fill(Color.white.opacity(0.2))
							.frame(width: 44, height: 44)
						Image(systemName: "clock.fill")
							.font(.system(size: 20, weight: .semibold))
							.foregroundStyle(.white)
					}
					Spacer()
					Text("NEW ANALYTICS")
						.font(.caption2.weight(.semibold))
						.foregroundStyle(Color.white.opacity(0.85))
						.padding(.horizontal, 10)
						.padding(.vertical, 5)
						.background(Capsule().fill(Color.white.opacity(0.15)))
				}

				Spacer(minLength: 12)

				Text("タイムマシン")
					.font(.title2.weight(.bold))
					.foregroundStyle(.white)
				Text("直近1ヶ月のヘビロテ曲")
					.font(.subheadline)
					.foregroundStyle(Color.white.opacity(0.9))
					.padding(.top, 4)

				Spacer(minLength: 20)

				HStack {
					HStack(spacing: -8) {
						ForEach(0..<3, id: \.self) { i in
							ZStack {
								Circle()
									.strokeBorder(Color.white.opacity(0.35), lineWidth: 2)
									.background(Circle().fill(IntentTabInsightStyle.timeMachineGradientBottom.opacity(0.9)))
									.frame(width: 36, height: 36)
								Image(systemName: "music.note")
									.font(.system(size: 14, weight: .semibold))
									.foregroundStyle(.white.opacity(0.95))
							}
							.zIndex(Double(3 - i))
						}
					}
					Spacer()
					Button(action: onTapLookBack) {
						Text("振り返る")
							.font(.subheadline.weight(.semibold))
							.foregroundStyle(IntentTabInsightStyle.timeMachineGradientBottom)
							.padding(.horizontal, 22)
							.padding(.vertical, 12)
							.background(Capsule().fill(Color.white))
					}
					.buttonStyle(.plain)
				}
			}
			.padding(22)
		}
		.frame(height: 220)
	}
}

#Preview {
	TimeMachineInsightCardView(onTapLookBack: {})
		.padding()
		.background(IntentTabInsightStyle.pageBackground)
}
