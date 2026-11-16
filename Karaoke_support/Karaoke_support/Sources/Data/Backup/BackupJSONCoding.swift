#if DEBUG || BETA
import Foundation

/// バックアップの中身を JSON にする書き方と、JSON から戻す読み方（ADR 0058・0061）。
/// 同じ記録なら同じバイト列になるように、鍵の順をそろえる。日時は秒より下も残し、読むときも秒より下まで戻す（取り込んだときに並びが変わらないように）。
@MainActor
enum BackupJSONCoding {
	static let encoder: JSONEncoder = {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]
		encoder.dateEncodingStrategy = .custom { date, encoder in
			var container = encoder.singleValueContainer()
			try container.encode(date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
		}
		return encoder
	}()

	/// 秒より下のある日時を読み、なければ秒までの日時として読む。
	static let decoder: JSONDecoder = {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .custom { decoder in
			let container = try decoder.singleValueContainer()
			let text = try container.decode(String.self)
			if let date = try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
				return date
			}
			if let date = try? Date(text, strategy: Date.ISO8601FormatStyle()) {
				return date
			}
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO 8601 date.")
		}
		return decoder
	}()
}
#endif
