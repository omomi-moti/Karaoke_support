import SwiftUI

/// アプリ共通のセマンティック色（`Assets.xcassets` の Color Set と 1:1）。
///
/// アセットカタログの **Swift シンボル生成**（`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`）により **`Color(.app…)`** で参照し、リネーム・タイポをコンパイル時に検出する。
///
/// V1 はダーク寄せ UI 前提。**ライトモードは未対応**（`docs/design/color_tokens_v1.md`）。将来は各 Set に Appearance を追加する。
enum AppColor {
	static let backgroundGradientStart = Color(.appBackgroundGradientStart)
	static let backgroundGradientEnd = Color(.appBackgroundGradientEnd)
	static let textPrimary = Color(.appTextPrimary)
	static let textSecondary = Color(.appTextSecondary)
	static let textTertiary = Color(.appTextTertiary)
	static let surfaceCard = Color(.appSurfaceCard)
	static let borderSubtle = Color(.appBorderSubtle)
	static let accentScore = Color(.appAccentScore)
	static let badgeShoutBackground = Color(.appBadgeShoutBackground)
	static let badgeShoutForeground = Color(.appBadgeShoutForeground)
	static let badgeEmoBackground = Color(.appBadgeEmoBackground)
	static let badgeEmoForeground = Color(.appBadgeEmoForeground)
	static let badgePracticeBackground = Color(.appBadgePracticeBackground)
	static let badgePracticeForeground = Color(.appBadgePracticeForeground)
	static let filterChipSelectedBackground = Color(.appFilterChipSelectedBackground)
	static let filterChipUnselectedBackground = Color(.appFilterChipUnselectedBackground)
	static let foregroundSubtle = Color(.appForegroundSubtle)
	static let semanticError = Color(.appSemanticError)
}
