#if DEBUG || BETA
import Foundation

/// 送る処理の結果のうち、失敗でないもの。失敗は ``BackupFailure`` を投げる。
enum BackupOutcome: Equatable, Sendable {
	/// 送れた。
	case uploaded
	/// オフか、今の版の同意がないので送らなかった。
	case notActive
	/// 端末に記録が 1 件もないので送らなかった（FR-5）。
	case noRecords
	/// 前回送った中身と同じなので送らなかった。
	case unchanged
	/// 前回が 412 で、本人が確かめるまで自動では送らない。
	case waitingForConfirmation
	/// 前に戻ったときで、前回はやり直す失敗ではなかったので送らなかった。
	case nothingToRetry
}
#endif
