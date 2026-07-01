# refactor/i-r007-unify-background-color 実装ログ

**日付**: 2026-07-01
**対象**: [I-R007] 画面間の背景色を統一（GitHub Issue #83）

---

## 概要

履歴画面（`HistoryListView`）にのみ適用されていたダークグラデーション背景（`AppColor.backgroundGradientStart` → `backgroundGradientEnd`）を、選曲タブ・検索シート・設定タブ・歌唱記録シートにも適用し、画面間の背景色を統一した。

Issue #83 の「影響範囲」に加え、「その他背景未指定の画面がないか確認する」タスクに沿って全画面を洗い出し、対応範囲を拡張した。

---

## 対応の流れ

作業は Issue #83 の対応内容に沿って、以下の順で進めた。

1. **Issue の特定**: リモートの GitHub Issue を検索し、`[I-R007] 画面間の背景色を統一`（#83）が該当することを確認。ブランチ名はプロジェクトの命名規則（`refactor/i-r{番号}-{内容}`）に沿って `refactor/i-r007-unify-background-color` とした。
2. **`SongsRootView` に背景を適用**: `NavigationStack` 内の `VStack` に `LinearGradient(backgroundGradientStart → backgroundGradientEnd)` を追加。
3. **`SearchContainerView` に背景を適用**: シート全体を包む `VStack` に同じグラデーションを追加。
4. **`SearchView` の `List` 背景が透過していない問題を発見・修正**: `List` のデフォルト背景（システム色）がグラデーションを隠していたため `.scrollContentBackground(.hidden)` を追加。
5. **検索結果カードが「浮いて見える」問題を発見・修正**: `List` の各行にデフォルトの行背景・セパレーターが残っていたことが原因と判明。`HistoryListView` の `List` 実装（`.listRowInsets` / `.listRowSeparator(.hidden)` / `.listRowBackground(Color.clear)`）と同じ設定を `SearchView` にも追加し解消。
6. **`List` vs `ScrollView + LazyVStack` の設計検討**: 一度は「スワイプ操作等が無いなら `ScrollView + LazyVStack` の方がシンプル」と提案したが、次の理由で `List` 継続を採用（提案は撤回）。
   - `HistoryListView` と同じ「リストの作り方」を踏襲でき、アプリ内でリスト実装パターンが割れない
   - 検索結果は意味的に「リスト」であり、`List` の方が VoiceOver 等のアクセシビリティ上正しい
   - `listRowInsets` 等 3 つの modifier は Apple 標準的なカスタムリストの定番セットであり、過剰なカスタマイズではない
   - 将来のスワイプ操作追加（検索履歴削除等）にも自然に拡張できる
7. **残りの背景未指定画面を洗い出し**: `Sources/Presentation/**/*View.swift` を全走査し、背景指定の有無を確認。
   - `SettingsRootView`: 背景指定なし → グラデーションを追加
   - `RecordingSheetContentView`（歌唱記録シート本体・新規/編集共通）: 背景指定なし → 追加
   - `RecordingSheetContainerView`（ロードエラー時・ViewModel 構築前の一時表示）: 背景指定なし → 追加（白画面フラッシュの回避も兼ねる）
   - `TimeMachineRankingSheetView` / `MyAnthemRankingSheetView`: `IntentTabInsightStyle.rankingSheetBackground`（紫系）が既に意図的に設定済みのため対象外と判断
   - `HistoryListView`: 対応済みのため対象外

---

## 変更ファイル

| ファイル | 変更内容 |
|---|---|
| `Sources/Presentation/Songs/SongsRootView.swift` | `NavigationStack` 内 `VStack` に背景グラデーションを追加 |
| `Sources/Presentation/Search/SearchContainerView.swift` | シート全体の `VStack` に背景グラデーションを追加 |
| `Sources/Presentation/Search/SearchView.swift` | `List` に `.scrollContentBackground(.hidden)` / 各行に `.listRowInsets` `.listRowSeparator(.hidden)` `.listRowBackground(Color.clear)` を追加 |
| `Sources/Presentation/Settings/SettingsRootView.swift` | `EmptyPlaceholderView` に背景グラデーションを追加 |
| `Sources/Presentation/Recording/Sheet/RecordingSheetContentView.swift` | `ZStack` 直下に背景グラデーションを追加 |
| `Sources/Presentation/Recording/Sheet/RecordingSheetContainerView.swift` | ロードエラー表示・ViewModel 構築前の一時表示に背景グラデーションを追加 |

---

## 設計判断

### 共通 `ViewModifier` 化は見送り

各画面に `LinearGradient(...).ignoresSafeArea()` をそのまま複製した。共通 `ViewModifier`（例: `.appBackground()`）を作る案も検討したが、今回のスコープは「背景色の統一」自体であり、抽象化の追加は別関心事と判断し見送った。将来同様の重複が増える場合は改めて検討する。

### `List` の行装飾を打ち消す方針を採用（`ScrollView` への置き換えは不採用）

上記「対応の流れ」6. の通り。`HistoryListView` との一貫性を優先した。

### `List → ScrollView + LazyVStack` のような構造リファクタリングはこのブランチでは実施しない

背景色統一のスコープを超えるため、実施する場合は別 Issue・別ブランチで対応する方針とした。

---

## テスト・確認

- 自動テストの追加は無し（見た目のみの変更のため）。
- `xcodebuild` はローカル環境で Command Line Tools のみのため実行不可（Xcode 本体が必要）。SourceKit 診断は単体ファイル解析の制約によるもので、今回の変更に起因するエラーは無いことをコードレビューで確認。
- 手動確認: 検索シートでカードの浮き表示が解消されたことをスクリーンショットで確認済み。

---

## 参照

- Issue 定義: GitHub Issue #83（`[I-R007] 画面間の背景色を統一`）
- 参照トークン: `AppColor.backgroundGradientStart` / `AppColor.backgroundGradientEnd`（`Sources/Presentation/Theme/AppColor.swift`）
- 既存実装パターン: `HistoryListView`（`Sources/Presentation/History/List/HistoryListView.swift`）

以上。
