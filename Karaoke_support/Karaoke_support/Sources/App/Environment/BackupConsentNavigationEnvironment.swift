#if DEBUG || BETA
import SwiftUI

extension EnvironmentValues {
	/// バックアップの同意の画面を、`RootView` のシートで出す（#197、ADR 0072）。空の画面で取り込んだあと、オンにすると選んだときに使う。
	@Entry var navigateToBackupConsent: () -> Void = {}
}
#endif
