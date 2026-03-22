import SwiftUI

/// アプリ共通のセマンティック色（`Assets.xcassets` の Color Set 名と 1:1）。
///
/// V1 はダーク寄せ UI 前提。**ライトモードは未対応**（`docs/design/color_tokens_v1.md`）。将来は各 Set に Appearance を追加する。
enum AppColor {
	static let backgroundGradientStart = Color("AppBackgroundGradientStart")
	static let backgroundGradientEnd = Color("AppBackgroundGradientEnd")
	static let textPrimary = Color("AppTextPrimary")
	static let textSecondary = Color("AppTextSecondary")
	static let textTertiary = Color("AppTextTertiary")
	static let surfaceCard = Color("AppSurfaceCard")
	static let borderSubtle = Color("AppBorderSubtle")
	static let accentScore = Color("AppAccentScore")
	static let badgeShoutBackground = Color("AppBadgeShoutBackground")
	static let badgeShoutForeground = Color("AppBadgeShoutForeground")
	static let badgeEmoBackground = Color("AppBadgeEmoBackground")
	static let badgeEmoForeground = Color("AppBadgeEmoForeground")
	static let badgePracticeBackground = Color("AppBadgePracticeBackground")
	static let badgePracticeForeground = Color("AppBadgePracticeForeground")
	static let filterChipSelectedBackground = Color("AppFilterChipSelectedBackground")
	static let filterChipUnselectedBackground = Color("AppFilterChipUnselectedBackground")
	static let foregroundSubtle = Color("AppForegroundSubtle")
	static let semanticError = Color("AppSemanticError")
}
