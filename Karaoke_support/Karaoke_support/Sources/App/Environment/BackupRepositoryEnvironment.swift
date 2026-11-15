#if DEBUG || BETA
import SwiftUI

// accountRepository と同じく、初期値は nil にする（ADR 0031・0055）。つなぎ先がないビルドで、偽のバックアップの欄が出ないようにするため。

extension EnvironmentValues {
	/// 記録のバックアップの Repository。nil のときはバックアップの欄を出さない。
	@Entry var backupRepository: (any BackupRepositoryProtocol)? = nil
}
#endif
