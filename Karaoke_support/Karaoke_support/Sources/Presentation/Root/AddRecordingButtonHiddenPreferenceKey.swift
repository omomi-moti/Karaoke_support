import SwiftUI

/// タブの上に重ねている＋ボタン（新規記録）を隠したい画面が `true` を立てる。
/// 履歴から開いた記録の編集画面は、＋ボタンが保存ボタンに重なり、押すと編集中に新規記録が始まってしまうため隠す。
struct AddRecordingButtonHiddenPreferenceKey: PreferenceKey {
	static let defaultValue = false

	static func reduce(value: inout Bool, nextValue: () -> Bool) {
		value = value || nextValue()
	}
}
