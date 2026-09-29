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

---

## 画面背景の方針（I-R007）

- **標準**: 通常の画面・シートは `AppBackgroundGradientStart` → `AppBackgroundGradientEnd` のダークグラデーションを背景に使う。実装は個別に `LinearGradient` を書かず、共通コンポーネント **`AppBackgroundGradientView`**（`Sources/Presentation/Theme/AppBackgroundGradientView.swift`）と `View.appBackgroundGradient()` を使う。
  - 対象: 履歴（`HistoryListView`）、選曲タブ（`SongsRootView`）、検索シート（`SearchContainerView`）、設定タブ（`SettingsRootView`）、歌唱記録シート（`RecordingSheetContentView` / `RecordingSheetContainerView`）
- **例外**: インサイトのランキングシート（`TimeMachineRankingSheetView` / `MyAnthemRankingSheetView`）は `IntentTabInsightStyle.rankingSheetBackground`（紫系の単色）を使う。インサイト系の世界観を独立させる意図的な差別化であり、標準グラデーションへの統一対象ではない。
- **新規画面を追加する場合**: 上記「標準」に該当する一般画面・シートであれば `appBackgroundGradient()` を使う。インサイト系のような独自ブランディングが必要な場合のみ専用の背景トークンを検討する。

---

## 起動画面（Launch Screen）

- **方針**: Apple HIG に従い「最初の画面とほぼ同じ見た目の、何もない画面」。ロゴを大きく出すスプラッシュは作らない。
- **定義場所**: `Karaoke_support/Info.plist` の `UILaunchScreen` 辞書が唯一の定義（`GENERATE_INFOPLIST_FILE = YES` の生成キーとビルド時にマージされる）。
  - `INFOPLIST_KEY_UILaunchScreen_UIColorName` 等のビルド設定は **Info.plist に出力されない**ため使わない。
  - プロジェクトは同期フォルダ（`PBXFileSystemSynchronizedRootGroup`）なので、`Info.plist` はターゲットのメンバーシップから除外している（リソースとしてコピーされると「Multiple commands produce」になる）。
- **背景色**: `AppLaunchBackground`。値は **`AppBackgroundGradientStart` と同じに保つ**（Asset Catalog に色の参照機能はないため二重管理。どちらかを変えたらもう片方も直す）。ライト用 Appearance を追加するときも両方同時に増やす。
- **ロゴを出す場合（アイコン確定後）**: Image Set `AppLaunchLogo` を追加し、`UILaunchScreen` に `UIImageName = AppLaunchLogo` を足す。
- **確認手順**: 起動画面は iOS 側のキャッシュが残りやすい。**アプリを削除してから再インストール**し、ライト／ダーク両モードで白いチラつきがないことを確認する。
