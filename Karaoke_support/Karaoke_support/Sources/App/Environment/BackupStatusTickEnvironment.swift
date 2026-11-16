#if DEBUG || BETA
import SwiftUI

// 初期値は値型なので、読むたびに作り直しても困らない。そのため @Entry で書く（ADR 0031）。

extension EnvironmentValues {
	/// 裏に回ったとき・前に戻ったときの送る処理が終わるたびに増える。設定のバックアップの欄は、この変化で状態を読み直す。
	@Entry var backupStatusTick: Int = 0
}
#endif
