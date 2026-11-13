#if DEBUG || BETA
import Foundation

/// 設定に出すバックアップの状態。端末の `UserDefaults` に置く 5 つのうち、画面に要るものだけを持つ（ADR 0058）。
struct BackupStatus: Equatable, Sendable {
	/// 同意の画面の版。送る項目を増やしたら上げ、同意を取り直すまで送らない。
	static let currentConsentVersion = 1

	let isEnabled: Bool
	let consentVersion: Int?
	let lastSucceededAt: Date?
	let lastFailure: BackupFailure?

	/// オンで、今の版の同意があるか。`false` なら送らない。
	var isActive: Bool {
		isEnabled && consentVersion == Self.currentConsentVersion
	}
}
#endif
