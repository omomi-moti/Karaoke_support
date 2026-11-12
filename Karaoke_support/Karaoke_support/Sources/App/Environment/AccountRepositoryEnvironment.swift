#if DEBUG || BETA
import SwiftUI

// 初期値は nil で、読むたびに作り直しても同じなので @Entry で書く（ADR 0031）。
// ほかの Repository と違い、プレビュー用の偽物を初期値にしない。つなぎ先がないビルドで、本物のアプリに偽のアカウントが出ないようにするため（ADR 0055）。

extension EnvironmentValues {
	/// サーバーのアカウントの Repository。nil のときはアカウントの欄を出さない。
	@Entry var accountRepository: (any AccountRepositoryProtocol)? = nil
}
#endif
