import SwiftUI

// App 層で EnvironmentKey を定義する（`.cursorrules` の DI 方針）。

private struct ManualRecordingNavigationKey: EnvironmentKey {
	static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
	/// 選曲タブへ切り替え、手動曲名入力から記録フローへ進む（履歴 Empty State 等から）。
	var navigateToManualRecording: () -> Void {
		get { self[ManualRecordingNavigationKey.self] }
		set { self[ManualRecordingNavigationKey.self] = newValue }
	}
}
