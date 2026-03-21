import SwiftUI

/// 履歴1件のカード行（I-014）。ダークカード・右寄せスコア。
struct HistorySessionRowView: View {
	let session: SingingSession

	private static let performedAtFormatter: DateFormatter = {
		let f = DateFormatter()
		f.locale = Locale(identifier: "ja_JP")
		f.dateStyle = .medium
		f.timeStyle = .short
		return f
	}()

	var body: some View {
		HStack(alignment: .top, spacing: 12) {
			VStack(alignment: .leading, spacing: 6) {
				Text(TrackDisplayTitle.primary(for: session.track))
					.font(.headline.weight(.semibold))
					.foregroundStyle(Color.white)
					.multilineTextAlignment(.leading)

				Text(Self.performedAtFormatter.string(from: session.performedAt))
					.font(.subheadline)
					.foregroundStyle(Color.white.opacity(0.55))

				HistoryIntentBadgeView(intent: session.intent)
			}
			.frame(maxWidth: .infinity, alignment: .leading)

			VStack(alignment: .trailing, spacing: 2) {
				Text(formatScore(session.score))
					.font(.system(size: 30, weight: .bold, design: .rounded))
					.foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.58))
					.minimumScaleFactor(0.7)
					.lineLimit(1)

				Text("SCORE")
					.font(.caption2.weight(.semibold))
					.foregroundStyle(Color.white.opacity(0.45))
					.textCase(.uppercase)
			}
			.accessibilityElement(children: .combine)
			.accessibilityLabel("スコア \(formatScore(session.score))")
		}
		.padding(16)
		.background(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.fill(Color.white.opacity(0.08))
		)
		.overlay(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.stroke(Color.white.opacity(0.1), lineWidth: 1)
		)
	}

	private func formatScore(_ value: Double) -> String {
		String(format: "%.1f", value)
	}
}

#Preview("Row") {
	HistorySessionRowView(
		session: SingingSession(
			track: Track(userEnteredName: "アイドル"),
			intent: .shout,
			performedAt: .now,
			score: 92.5
		)
	)
	.padding()
	.background(Color.black)
}
