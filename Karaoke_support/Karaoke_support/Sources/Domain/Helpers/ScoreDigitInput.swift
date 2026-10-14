import Foundation

/// 右詰めで打つカラオケの点数（小数第3位まで）。
///
/// 数字を打つたびに右から押し出す（`9` → `0.009`、`92345` → `92.345`）。小数点は打たない。
/// 入力中は千分の一点を単位とする整数で持ち、`Double` の表現誤差を持ち込まない。
struct ScoreDigitInput: Equatable, Sendable {
	static let fractionDigits = 3
	/// 100.000 点。
	static let maxThousandths = 100_000

	/// まだ何も打っていないときは `nil`。
	private(set) var thousandths: Int?

	init() {}

	/// 既存の点数から始める（編集時）。小数第4位以下は四捨五入し、0〜100 に収める。
	init(score: Double) {
		let rounded = Int((score * 1000).rounded())
		thousandths = min(Self.maxThousandths, max(0, rounded))
	}

	var value: Double? {
		thousandths.map { Double($0) / 1000 }
	}

	/// `92.345` の形。未入力なら `nil`。
	var displayText: String? {
		guard let thousandths else { return nil }
		return "\(thousandths / 1000).\(String(format: "%03d", thousandths % 1000))"
	}

	/// 打った数字だけを並べた形（`92.345` なら `92345`）。未入力なら空文字。
	var enteredDigits: String {
		thousandths.map(String.init) ?? ""
	}

	/// 入力欄で編集された文字列から数字だけを読み直す。
	///
	/// - 数字が無い、または 0 しか無いときは未入力に戻す（`0.001` から消していったときに `0.000` で止まらないように）。
	/// - 100.000 を超える場合は打たなかったことにする。
	mutating func applyEditedText(_ text: String) {
		let digits = text.filter { ("0"..."9").contains($0) }.drop { $0 == "0" }
		guard !digits.isEmpty else {
			thousandths = nil
			return
		}
		guard digits.count <= 6, let next = Int(digits), next <= Self.maxThousandths else { return }
		thousandths = next
	}
}
