import SwiftUI

// App 層で EnvironmentValues を拡張する（CLAUDE.md の DI 方針）。
// 初期値は同一性のないクロージャなので、読むたびに作り直しても困らない。そのため @Entry で書く（ADR 0031）。

extension EnvironmentValues {
	/// 選曲タブへ切り替え、手動曲名入力から記録フローへ進む（履歴 Empty State 等から）。
	@Entry var navigateToManualRecording: () -> Void = {}
}
