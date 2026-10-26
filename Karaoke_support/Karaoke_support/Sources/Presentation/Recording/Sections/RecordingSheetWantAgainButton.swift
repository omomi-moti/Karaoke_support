import SwiftUI

/// 記録シートの「また歌いたい」（ハート）のボタン（#124）。
///
/// ON にした瞬間だけ、ハートが弾けて粒が散り、真上に「また歌いたい」の吹き出しを約 1.6 秒出す。OFF にしたときは出さない。
/// 「視差効果を減らす」が ON のときは動かさず、吹き出しを出してから消すだけにする。
struct RecordingSheetWantAgainButton: View {
	@Binding var isOn: Bool
	var isDisabled = false

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	/// ON にした回数。増えるたびに吹き出しを出し直す。
	@State private var popCount = 0
	/// 弾けるアニメーションを出した回数。視差効果を減らすときは増やさない。
	@State private var burstCount = 0
	@State private var isBubbleVisible = false

	static let bubbleDuration: Duration = .milliseconds(1600)
	private static let size: CGFloat = 56
	private static let particleCount = 8
	private static let burstRadius: CGFloat = 38

	var body: some View {
		Button(action: toggle) {
			Image(systemName: isOn ? "heart.fill" : "heart")
				.font(.system(size: 24, weight: .semibold))
				.foregroundStyle(isOn ? Color.white : AppColor.textSecondary)
				.symbolEffect(.bounce, value: burstCount)
				.frame(width: Self.size, height: Self.size)
				.background(Circle().fill(isOn ? AppColor.accentScore : Color.clear))
				.overlay(Circle().strokeBorder(isOn ? Color.clear : AppColor.borderSubtle, lineWidth: 1.5))
				.contentShape(Circle())
		}
		.buttonStyle(.plain)
		.disabled(isDisabled)
		.background { particles }
		.overlay(alignment: .bottomLeading) { bubble }
		.accessibilityLabel("また歌いたい")
		.accessibilityAddTraits(isOn ? .isSelected : [])
		.task(id: popCount) {
			guard popCount > 0 else { return }
			try? await Task.sleep(for: Self.bubbleDuration)
			guard !Task.isCancelled else { return }
			withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
				isBubbleVisible = false
			}
		}
	}

	private func toggle() {
		isOn.toggle()
		guard isOn else {
			isBubbleVisible = false
			return
		}
		popCount += 1
		withAnimation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.4)) {
			isBubbleVisible = true
		}
		if !reduceMotion {
			burstCount += 1
		}
	}

	private var particles: some View {
		KeyframeAnimator(initialValue: 1.0, trigger: burstCount) { progress in
			ZStack {
				ForEach(0..<Self.particleCount, id: \.self) { index in
					let angle = Double(index) / Double(Self.particleCount) * 2 * .pi
					Circle()
						.fill(AppColor.accentScore)
						.frame(width: 6, height: 6)
						.offset(
							x: cos(angle) * Self.burstRadius * progress,
							y: sin(angle) * Self.burstRadius * progress
						)
						.opacity(1 - progress)
				}
			}
		} keyframes: { _ in
			MoveKeyframe(0.0)
			CubicKeyframe(1.0, duration: 0.5)
		}
		.allowsHitTesting(false)
		.accessibilityHidden(true)
	}

	@ViewBuilder
	private var bubble: some View {
		if isBubbleVisible {
			VStack(alignment: .leading, spacing: 0) {
				Text("また歌いたい")
					.font(.caption.weight(.bold))
					.foregroundStyle(.white)
					.fixedSize()
					.padding(.horizontal, 10)
					.padding(.vertical, 6)
					.background(AppColor.accentScore, in: Capsule())
				Image(systemName: "arrowtriangle.down.fill")
					.font(.system(size: 10))
					.foregroundStyle(AppColor.accentScore)
					.padding(.leading, Self.size / 2 - 5)
					.offset(y: -2)
			}
			.fixedSize()
			.padding(.bottom, Self.size + 4)
			.transition(reduceMotion ? .identity : .scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
			.allowsHitTesting(false)
			.accessibilityHidden(true)
		}
	}
}

#Preview {
	@Previewable @State var isOn = false
	RecordingSheetWantAgainButton(isOn: $isOn)
		.padding(80)
		.appBackgroundGradient()
}
