import Foundation

/// ランキング行などで表示する曲名ラベル（手入力名を優先）。
enum InsightTrackRowTitle {
	static func text(spotifyTrackId: String?, userEnteredName: String?) -> String {
		let user = userEnteredName?.trimmingCharacters(in: .whitespacesAndNewlines)
		if let user, !user.isEmpty { return user }
		let spotify = spotifyTrackId?.trimmingCharacters(in: .whitespacesAndNewlines)
		if let spotify, !spotify.isEmpty { return spotify }
		return "曲名未設定"
	}
}
