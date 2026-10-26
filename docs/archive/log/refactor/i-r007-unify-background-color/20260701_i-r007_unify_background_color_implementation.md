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
8. **重複の解消**: `SongsRootView` 等の `.background(LinearGradient(...))` が Songs/Search/Settings/Recording など複数画面にコピペで重複しており、将来トークンや角度を変える際に修正漏れが起きやすいと判断。共通 `ViewModifier` として切り出す方向に方針転換した（詳細は下記「設計判断」）。
9. **共通コンポーネント化**: `Sources/Presentation/Theme/AppBackgroundGradientView.swift` を新設し、`AppBackgroundGradientView`（View として直接配置する用）と `View.appBackgroundGradient()`（`.background()` として付ける用）を定義。6.〜7. で個別に書いた `LinearGradient(...).ignoresSafeArea()` を全箇所（`SongsRootView` / `SearchContainerView` / `SettingsRootView` / `RecordingSheetContentView` / `RecordingSheetContainerView` 2箇所）置き換え、あわせて既存の `HistoryListView` も同じ共通コンポーネントに揃えた。
10. **仕上げの修正**: 2点を追加対応。
    - `SearchContainerView` の `VStack` に明示的な `.frame(maxWidth: .infinity, maxHeight: .infinity)` が無く、他画面（`SettingsRootView`）と扱いが不揃いだった点を修正。`List`/`Spacer` の greedy な性質でたまたま全面表示になっていたが、明示的に指定して確実にした。
    - Issue #83 のチェックリストにある「`docs/design/color_tokens_v1.md` に方針を追記する」が未着手だったため、「画面背景の方針」セクションを追記（標準は `AppBackgroundGradientView` を使う、インサイト系ランキングシートは意図的に例外、というルールを明文化）。

---

## 変更ファイル

| ファイル | 変更内容 |
|---|---|
| `Sources/Presentation/Theme/AppBackgroundGradientView.swift`（新規） | 共通背景コンポーネント `AppBackgroundGradientView` と `View.appBackgroundGradient()` を定義 |
| `Sources/Presentation/Songs/SongsRootView.swift` | `NavigationStack` 内 `VStack` に `.appBackgroundGradient()` を適用 |
| `Sources/Presentation/Search/SearchContainerView.swift` | シート全体の `VStack` に `.frame(maxWidth/maxHeight: .infinity)` + `.appBackgroundGradient()` を適用 |
| `Sources/Presentation/Search/SearchView.swift` | `List` に `.scrollContentBackground(.hidden)` / 各行に `.listRowInsets` `.listRowSeparator(.hidden)` `.listRowBackground(Color.clear)` を追加 |
| `Sources/Presentation/Settings/SettingsRootView.swift` | `EmptyPlaceholderView` に `.appBackgroundGradient()` を適用 |
| `Sources/Presentation/Recording/Sheet/RecordingSheetContentView.swift` | `ZStack` 直下に `AppBackgroundGradientView()` を配置 |
| `Sources/Presentation/Recording/Sheet/RecordingSheetContainerView.swift` | ロードエラー表示・ViewModel 構築前の一時表示に `AppBackgroundGradientView` / `.appBackgroundGradient()` を適用 |
| `Sources/Presentation/History/List/HistoryListView.swift` | 既存の `LinearGradient` 直書きを `AppBackgroundGradientView()` に置き換え（一貫性のため） |
| `docs/design/color_tokens_v1.md` | 「画面背景の方針」セクションを追記（標準/例外ルールを明文化） |

---

## 設計判断

### 共通コンポーネント（`AppBackgroundGradientView` / `View.appBackgroundGradient()`）を採用

当初は各画面に `LinearGradient(...).ignoresSafeArea()` をそのまま複製し、「スコープは背景色の統一自体であり抽象化の追加は別関心事」として共通化を見送っていた。しかし同一の9行ブロックが6箇所まで重複し、将来トークンや角度を変える際に修正漏れが起きやすい状態になったため、方針を転換。`Sources/Presentation/Theme/AppBackgroundGradientView.swift` に集約し、各画面から `.appBackgroundGradient()` または `AppBackgroundGradientView()` を呼ぶ形に統一した。「3行程度の重複は許容するが早すぎる抽象化は避ける」という原則に対し、6箇所まで増えた時点は抽出が正当化される閾値と判断した。

### `List` の行装飾を打ち消す方針を採用（`ScrollView` への置き換えは不採用）

上記「対応の流れ」6. の通り。`HistoryListView` との一貫性を優先した。

### `List → ScrollView + LazyVStack` のような構造リファクタリングはこのブランチでは実施しない

背景色統一のスコープを超えるため、実施する場合は別 Issue・別ブランチで対応する方針とした。

### `docs/design/color_tokens_v1.md` に画面背景の方針を明記

標準画面は `AppBackgroundGradientView` を使うこと、インサイト系ランキングシート（`TimeMachineRankingSheetView` / `MyAnthemRankingSheetView`）は `IntentTabInsightStyle.rankingSheetBackground`（紫系）を使う意図的な例外であることをドキュメント化し、次に画面を追加する際の判断基準がブレないようにした。

---

## テスト・確認

- 自動テストの追加は無し（見た目のみの変更のため）。
- `xcodebuild` はローカル環境で Command Line Tools のみのため実行不可（Xcode 本体が必要）。SourceKit 診断は単体ファイル解析の制約によるもので、今回の変更に起因するエラーは無いことをコードレビューで確認。
- 手動確認: 検索シートでカードの浮き表示が解消されたことをスクリーンショットで確認済み。

---

## 参照

- Issue 定義: GitHub Issue #83（`[I-R007] 画面間の背景色を統一`）
- 参照トークン: `AppColor.backgroundGradientStart` / `AppColor.backgroundGradientEnd`（`Sources/Presentation/Theme/AppColor.swift`）
- 共通コンポーネント: `AppBackgroundGradientView`（`Sources/Presentation/Theme/AppBackgroundGradientView.swift`）
- デザイン方針: `docs/design/color_tokens_v1.md`「画面背景の方針（I-R007）」

以上。
