# V1 カラートークン（セマンティック）

**前提:** ダーク寄せの画面を主とする。**ライトモード用の Appearance は未追加**（I-014-A）。各 Color Set は **Any Appearance に 1 色**。

**参照実装:** `AppColor`（`Sources/Presentation/Theme/AppColor.swift`）が **生成シンボル** `Color(.appTextPrimary)` 等で `Assets.xcassets` と 1:1 対応（文字列 `Color("…")` は使わない）。

| Color Set | 用途（主） |
|-----------|------------|
| `AppBackgroundGradientStart` / `AppBackgroundGradientEnd` | 画面背景グラデーション |
| `AppTextPrimary` / `AppTextSecondary` / `AppTextTertiary` | 本文・補助・弱いラベル |
| `AppSurfaceCard` | カード塗り |
| `AppBorderSubtle` | カード枠線 |
| `AppAccentScore` | スコア強調（履歴・録音と揃える場合は同トークンを参照） |
| `AppBadge*Background` / `AppBadge*Foreground` | Intent ピル（Shout / Emo / Practice） |
| `AppFilterChipSelectedBackground` / `AppFilterChipUnselectedBackground` | 履歴フィルターチップ |
| `AppForegroundSubtle` | チップ非選択時などの白 85% |
| `AppSemanticError` | エラーメッセージ文言 |

**コントラスト:** 主要な「文字 × 背景」の組み合わせはデザインチェック推奨。**WCAG AA を目安にするか**はチームで合意。自動ツールでの網羅検証は V1 の必須にはしない。

**拡張:** 新規画面は可能な限り **リテラル `Color(red:...)` を増やさず**、不足分のみトークンを追加する。
