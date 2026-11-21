import SwiftUI

// App 層で EnvironmentValues を拡張する（CLAUDE.md の DI 方針）。
// 値なので @Entry で書く（ADR 0031）。

extension EnvironmentValues {
	/// 空の画面に、前の iPhone の記録は設定から取り込めると案内するか（ADR 0061・0070）。
	/// アカウントの欄があるビルド（Debug・Beta でつなぎ先があるとき）だけ `true` にする。
	@Entry var isRestoreHintVisible = false
}
