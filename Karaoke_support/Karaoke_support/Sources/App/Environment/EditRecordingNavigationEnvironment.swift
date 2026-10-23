import SwiftUI

// App 層で EnvironmentKey を定義する（`.cursorrules` の DI 方針）。

private struct EditRecordingNavigationKey: EnvironmentKey {
	static let defaultValue: (UUID) -> Void = { _ in }
}

extension EnvironmentValues {
	/// 履歴の記録を、`RootView` の記録シートで編集として開く。
	var navigateToEditRecording: (UUID) -> Void {
		get { self[EditRecordingNavigationKey.self] }
		set { self[EditRecordingNavigationKey.self] = newValue }
	}
}
