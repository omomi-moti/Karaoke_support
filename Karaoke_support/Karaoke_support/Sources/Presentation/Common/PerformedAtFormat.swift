import Foundation

/// 歌唱日時の表示フォーマット。端末のロケール設定に関わらず日本語表記に固定する。
enum PerformedAtFormat {
	/// 例: 2026/08/29 13:54
	static func dateTime(_ date: Date) -> String {
		dateTimeFormatter.string(from: date)
	}

	/// 例: 2026/08/29。時刻が不要な箇所（グラフの読み上げ等）で使う。
	static func dateOnly(_ date: Date) -> String {
		dateOnlyFormatter.string(from: date)
	}

	private static let dateTimeFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "ja_JP")
		formatter.dateStyle = .medium
		formatter.timeStyle = .short
		return formatter
	}()

	private static let dateOnlyFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "ja_JP")
		formatter.dateStyle = .medium
		formatter.timeStyle = .none
		return formatter
	}()
}
