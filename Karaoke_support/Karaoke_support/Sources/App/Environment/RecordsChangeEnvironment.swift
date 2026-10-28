import SwiftUI

// App 層で EnvironmentValues を拡張する（CLAUDE.md の DI 方針）。
// 初期値は同一性のないクロージャなので、読むたびに作り直しても困らない。そのため @Entry で書く（ADR 0031）。

extension EnvironmentValues {
	/// 記録シートを通さずに記録を変えたとき（曲詳細での削除など）に呼ぶ。`historyReloadTick` を増やし、履歴と曲詳細を読み直させる（#135）。
	@Entry var notifyRecordsChanged: () -> Void = {}
}
