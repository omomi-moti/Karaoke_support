import SwiftUI

// App 層で EnvironmentKey を定義する（`.cursorrules` の DI 方針）。

private struct HistoryReloadTickKey: EnvironmentKey {
	static let defaultValue = 0
}

extension EnvironmentValues {
	/// 記録を保存するたびに増える。履歴一覧はこの変化で再読み込みする（履歴タブ上でシートを開いて保存した場合も含む）。
	var historyReloadTick: Int {
		get { self[HistoryReloadTickKey.self] }
		set { self[HistoryReloadTickKey.self] = newValue }
	}
}
