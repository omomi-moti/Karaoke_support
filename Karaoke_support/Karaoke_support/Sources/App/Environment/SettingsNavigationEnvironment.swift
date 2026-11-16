import SwiftUI

// App 層で EnvironmentValues を拡張する（CLAUDE.md の DI 方針）。
// 初期値は nil で、読むたびに作り直しても同じなので @Entry で書く（ADR 0031）。

extension EnvironmentValues {
	/// 設定タブへ切り替える。空の画面から、前の iPhone の記録の取り込みへ案内するため（ADR 0061）。
	/// アカウントの欄がないビルド（Release・つなぎ先がないとき）では nil で、案内を出さない。
	@Entry var navigateToSettings: (() -> Void)? = nil
}
