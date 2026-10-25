import SwiftUI

// App 層で EnvironmentValues を拡張する（`.cursorrules` の DI 方針）。
// 初期値は値型なので、読むたびに作り直しても困らない。そのため @Entry で書く（ADR 0031）。

extension EnvironmentValues {
	/// 記録を保存するたびに増える。履歴一覧はこの変化で再読み込みする（履歴タブ上でシートを開いて保存した場合も含む）。
	@Entry var historyReloadTick: Int = 0
}
