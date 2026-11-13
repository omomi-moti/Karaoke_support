#if DEBUG || BETA
import Foundation

/// バックアップを送るきっかけ（ADR 0058）。どれも同じ送る処理を呼ぶ。
enum BackupTrigger: Equatable, Sendable {
	/// アプリが裏に回った。
	case background
	/// アプリが前に戻った。前回が自動でやり直してよい失敗だったときだけ送る。
	case foreground
	/// 設定の「今すぐバックアップ」。
	case manual
}
#endif
