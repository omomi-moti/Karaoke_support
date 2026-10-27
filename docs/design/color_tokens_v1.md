# V1 カラートークン（セマンティック）

**前提:** ライト／ダーク両対応。各 Color Set は **Any（ライト用）と Dark の 2 色**を持つ。新しく Set を足すときも必ず両方を定義する。

**参照実装:** `AppColor`（`Sources/Presentation/Theme/AppColor.swift`）が **生成シンボル** `Color(.appTextPrimary)` 等で `Assets.xcassets` と 1:1 対応（文字列 `Color("…")` は使わない）。

| Color Set | 用途（主） |
|-----------|------------|
| `AppBackgroundGradientStart` / `AppBackgroundGradientEnd` | 画面背景グラデーション |
| `AppTextPrimary` / `AppTextSecondary` / `AppTextTertiary` | 本文・補助・弱いラベル |
| `AppSurfaceCard` | カード塗り |
| `AppBorderSubtle` | カード枠線 |
| `AppAccentScore` | スコア強調（履歴・録音と揃える場合は同トークンを参照） |
| `AppBadge*Background` / `AppBadge*Foreground` | Intent ピル（Shout / Emo / Practice）。色味は `AppIntent*Accent` と同じ系統（ピンク／黄色／緑）で、文字が読めるよう背景と文字の 2 色に分けている |
| `AppIntentShoutAccent` / `AppIntentEmoAccent` / `AppIntentPracticeAccent` | 記録シートの気分ボタンと履歴のフィルターチップで、選んだときの枠・塗り・光（Shout はピンク、Emo は黄色、Practice は緑。`IntentPalette.accent` 経由） |
| `AppFilterChipUnselectedBackground` | 履歴フィルターチップの非選択時の塗り。選択時は気分のチップが `AppIntent*Accent`、「すべて」が `AppTextPrimary`（無彩色）を使う |
| `AppForegroundSubtle` | チップ非選択時の文字（ダーク: 白 85% / ライト: 黒 75%） |
| `AppSemanticError` | エラーメッセージ文言 |
| `AppAddButton` | 新規記録の＋ボタン（`RootView`）。ライト・ダークで同じ色にしている。Liquid Glass を通すと少し明るく見えるので、その分を見込んで濃いめの値にしている。実際の見え方で、白い＋との比は 4.71〜4.92:1、背景との差はダーク約 3.7:1・ライト 4.8:1 |
| `AppColor.editAccent`（Color Set ではなくシステムの青） | 記録の編集を表す色。履歴の「編集」スワイプと、編集画面の「編集中」の帯で使う。ライト／ダークは OS が出し分ける |

**コントラスト:** 主要な「文字 × 背景」の組み合わせはデザインチェック推奨。ライト用の値は、小さい文字に使う `AppTextTertiary` / `AppAccentScore` を白〜`#F5F5F8` の背景で 4.5:1 以上になるように決めている。**WCAG AA を目安にするか**はチームで合意。自動ツールでの網羅検証は V1 の必須にはしない。

**拡張:** 新規画面は可能な限り **リテラル `Color(red:...)` を増やさず**、不足分のみトークンを追加する。

---

## 画面背景の方針（I-R007）

- **標準**: 通常の画面・シートは `AppBackgroundGradientStart` → `AppBackgroundGradientEnd` のグラデーションを背景に使う。実装は個別に `LinearGradient` を書かず、共通コンポーネント **`AppBackgroundGradientView`**（`Sources/Presentation/Theme/AppBackgroundGradientView.swift`）と `View.appBackgroundGradient()` を使う。
  - 対象: 履歴（`HistoryListView`）、選曲タブ（`SongsRootView`）、検索シート（`SearchContainerView`）、設定タブ（`SettingsRootView`）、歌唱記録シート（`RecordingSheetContentView` / `RecordingSheetContainerView`）
- **新規画面を追加する場合**: 上記「標準」に該当する一般画面・シートであれば `appBackgroundGradient()` を使う。独自の見た目が必要な場合のみ専用の背景トークンを検討する。

---

## 起動画面（Launch Screen）

- **方針**: Apple HIG に従い「最初の画面とほぼ同じ見た目の、何もない画面」。ロゴを大きく出すスプラッシュは作らない。
- **定義場所**: `Karaoke_support/Info.plist` の `UILaunchScreen` 辞書が唯一の定義（`GENERATE_INFOPLIST_FILE = YES` の生成キーとビルド時にマージされる）。
  - `INFOPLIST_KEY_UILaunchScreen_UIColorName` 等のビルド設定は **Info.plist に出力されない**ため使わない。
  - プロジェクトは同期フォルダ（`PBXFileSystemSynchronizedRootGroup`）なので、`Info.plist` はターゲットのメンバーシップから除外している（リソースとしてコピーされると「Multiple commands produce」になる）。
- **背景色**: `AppLaunchBackground`。値は **`AppBackgroundGradientStart` と同じに保つ**（Asset Catalog に色の参照機能はないため二重管理。どちらかを変えたらもう片方も直す）。ライト／ダークの両方を揃える。
- **ロゴ**: Image Set `AppLaunchLogo` を `UIImageName` で中央に表示（**試作。アイコン確定時に差し替え**）。
  - テーマと喧嘩しないよう `AppForegroundSubtle` と同じ値の単色（**ダーク: 白 85% / ライト: 黒 75%**）。起動画面では色を後から付けられないため、PNG 自体にこの色を焼き込み、Image Set の Appearance で出し分けている（ライト用は `AppLaunchLogo-Light@2x/3x.png`）。
  - 起動画面の画像は拡大縮小されず**そのままのポイントサイズ**で出るので、96pt 相当（@2x 192px / @3x 288px）で書き出している。大きさを変えるときは画像を作り直す。
  - 差し替え手順: アイコン原画から白背景を抜いて上記の色・サイズで書き出し、`AppLaunchLogo.imageset` の @2x / @3x をライト用・ダーク用の両方とも置き換える。ロゴをやめるときは `UIImageName` を消す。
- **確認手順**: 起動画面は iOS 側のキャッシュが残りやすい。**アプリを削除してから再インストール**し、ライト／ダーク両モードで白いチラつきがないことを確認する。
  - 起動画面は iOS が画像として作り、アプリのデータ領域の `Library/SplashBoard` にキャッシュする。**シミュレータの再起動では作り直されない**。
  - それでも古いままなら、シミュレータではデータを消さずにキャッシュだけ消せる:
    `rm -rf "$(xcrun simctl get_app_container booted com.omomimoti.hitokaralog data)/Library/SplashBoard"` の後にアプリを起動し直す。
