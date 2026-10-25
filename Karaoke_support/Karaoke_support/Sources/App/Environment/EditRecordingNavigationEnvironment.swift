import SwiftUI

// App 層で EnvironmentValues を拡張する（`.cursorrules` の DI 方針）。
// 初期値は同一性のないクロージャなので、読むたびに作り直しても困らない。そのため @Entry で書く（ADR 0031）。

extension EnvironmentValues {
	/// 履歴の記録を、`RootView` の記録シートで編集として開く。
	@Entry var navigateToEditRecording: (UUID) -> Void = { _ in }
}
