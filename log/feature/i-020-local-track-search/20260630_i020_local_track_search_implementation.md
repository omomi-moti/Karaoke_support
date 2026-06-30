# feature/i-020-local-track-search 実装ログ

**日付**: 2026-06-30  
**対象**: [I-020] ローカル曲名検索UI

---

## 概要

選曲タブにローカル曲名検索機能を追加した。SwiftData に保存済みの `Track` を `userEnteredName` の部分一致で検索し、検索結果から記録シートを開けるようにする。検索は `localizedStandardContains` を使用し、大文字・小文字／全角・半角／アクセント記号を区別しない（iOS 標準の Spotlight 検索と同等の挙動）。

あわせて、シートヘッダー（タイトル + X ボタン）を **`SheetHeaderView`** として共通コンポーネント化し、検索シート・記録シートで見た目を統一した。

---

## v1_issues タスク対応表

| 要件 | 実装の要点 |
|------|------------|
| 曲名検索 TextField | `SearchView` に `TextField("曲名を検索")` を配置。`.task(id: viewModel.searchText)` で入力変更を検知し検索を実行 |
| 検索結果の表示 | `SearchResultRowView` で角丸カード表示。曲名（`TrackDisplayTitle.primary`）・歌唱回数（`music.mic` アイコン）・最終歌唱日を表示 |
| 検索結果から記録シートへの遷移 | 行タップで `SelectedTrack` を組み立て、`SongsRootView` の `presentedRecordingRoute = .recording(selected)` で記録シートを開く |
| 大文字小文字の区別なし | `SwiftDataTrackRepository.searchLocal` で `contains` → `localizedStandardContains` に変更 |
| シートヘッダー統一 | `SheetHeaderView`（`Sources/Presentation/Common/`）を新設。`RecordingSheetContentView` の自前 `sheetHeader` を置換 |

---

## レイヤー別の責務

### `SearchViewModel`（`Presentation/Search`）

- `@Observable` / `@MainActor`。
- **`search(query:)`**: `searchGeneration`（`UInt`）による非同期レース防止。既存の `HistoryViewModel.loadGeneration` / `IntentTabViewModel.loadGeneration` と同じパターンを踏襲。
- **300ms デバウンス**: `Task.sleep(for: .milliseconds(300))` でキーストロークごとの即時検索を抑制。キャンセル時は `CancellationError` で早期リターン。
- **エラーハンドリング**: 失敗時は `errorMessage` に固定メッセージを設定（FR-011 準拠）。

### `SearchView`

- `@Bindable var viewModel: SearchViewModel` で ViewModel を受け取る。
- **`.task(id: viewModel.searchText)`** で入力変更を検知し `viewModel.search(query:)` を呼ぶ。SwiftUI が前の Task を自動キャンセルするため、デバウンスの `Task.sleep` が `CancellationError` で中断される。
- `TextField` を VStack 先頭に固定配置し、キーボード表示時のレイアウト崩れを防止。

### `SearchResultRowView`

- `Track` を受け取り、角丸カード（`AppColor.surfaceCard` + `borderSubtle`）で表示。
- `track.sessions` リレーションから最終歌唱日を取得（`sorted` + `first`）。
- 履歴カード（`HistorySessionRowView`）と同じ `AppColor` トークン・角丸スタイルで視覚的一貫性を確保。

### `SearchContainerView`

- シートのラッパー。`SheetHeaderView(title: "検索")` + `SearchView` を `VStack(spacing: 0)` で組み合わせ。
- `TrackRepositoryProtocol` を `init` で受け取り、`SearchViewModel` を `@State(initialValue:)` で生成（`HistoryListContainerView` / `IntentTabContainerView` と同じ Container View パターン）。
- `onSelectTrack: (SelectedTrack) -> Void` コールバックで選択結果を親に返す。

### `SheetHeaderView`（`Presentation/Common`）

- タイトル + X ボタンの共通シートヘッダー。
- `isDisabled: Bool`（デフォルト `false`）で保存中のボタン無効化に対応。
- `onDismiss: @escaping () -> Void` で閉じる処理を呼び出し側から注入。

### `SongsRootView`（変更）

- `@Environment(\.trackRepository)` を追加。
- ツールバーに虫眼鏡ボタン（`magnifyingglass`）を配置。
- `.sheet(isPresented: $isSearchPresented)` で `SearchContainerView` を表示。

### `RecordingSheetContentView`（変更）

- `private var sheetHeader` を削除し、`SheetHeaderView(title: recordingTitle, isDisabled: viewModel.isSaving)` に置換。

### `SwiftDataTrackRepository`（変更）

- `searchLocal(query:)` の `#Predicate` 内で `name.contains(searchQuery)` → `name.localizedStandardContains(searchQuery)` に変更。

---

## 表示・ナビゲーションの流れ

1. ユーザーが選曲タブのツールバー虫眼鏡ボタンをタップ → 検索シート（`.sheet`）が開く。
2. `TextField` に曲名を入力 → 300ms デバウンス後に `TrackRepository.searchLocal` で部分一致検索。
3. 検索結果の行をタップ → `SelectedTrack` を組み立て、`onSelectTrack` コールバックで親に返す。
4. `SearchContainerView` が `dismiss()` → `SongsRootView` が `presentedRecordingRoute = .recording(selected)` で記録シートを開く。
5. 該当なしの場合は「該当する曲が見つかりません」を表示。

---

## 設計判断

### `searchGeneration` の採用理由

`Task.cancel()` だけでは非同期キャンセルの完了を保証できない（キャンセルは協調的であり、`CancellationError` のチェックポイント間でデータが適用される可能性がある）。世代カウンタで古い結果を破棄するパターンは `HistoryViewModel` / `IntentTabViewModel` で実績があり、一貫性のために踏襲した。

### `.toolbar` 不使用（検索シート）

`NavigationStack` + `.toolbar` で X ボタンを配置すると、OS がツールバーボタンに自動装飾（グラス調の背景）を追加し、`RecordingSheetContentView` の自前ヘッダーと見た目が不一致になる。共通コンポーネント `SheetHeaderView` で自前 `HStack` ヘッダーに統一した。

### `localizedStandardContains`

iOS 標準の検索挙動（Spotlight・連絡先等）と同じロケール対応の部分一致。大文字小文字・全角半角・アクセント記号を区別しない。日本語の検索にも適している。

---

## テスト

### ユニットテスト

本実装では `SearchViewModel` / `SwiftDataTrackRepository.searchLocal` のユニットテストは **未追加**。今後の追加候補：

| 対象 | 検証内容 |
|------|----------|
| `SearchViewModel.search` | 空文字で結果クリア、300ms デバウンス、`searchGeneration` による古い結果の破棄、エラー時のメッセージ設定 |
| `SwiftDataTrackRepository.searchLocal` | 部分一致、大文字小文字の区別なし、`userEnteredName` が `nil` の Track を除外、`singCount` 降順 |

### 手動確認

- 選曲タブの虫眼鏡ボタンから検索シートが開くこと
- 曲名の部分一致で検索結果が表示されること
- 大文字・小文字／全角・半角で同じ結果が返ること
- 検索結果タップで記録シートが開くこと
- 検索シート・記録シートの X ボタンの見た目が統一されていること
- TextField にフォーカスしてもレイアウトが崩れないこと
- 該当なしの場合「該当する曲が見つかりません」が表示されること

---

## 参照

- Issue 定義: GitHub Issue #20
- Repository: `TrackRepositoryProtocol`, `SwiftDataTrackRepository`
- 選曲ルート: `SongsRecordingRoute`, `SelectedTrack`
- ナビゲーション方針: [`docs/v1_navigation_songs_recording.md`](../../docs/v1_navigation_songs_recording.md)
- 共通コンポーネント: `SheetHeaderView`（`Sources/Presentation/Common/SheetHeaderView.swift`）

以上。
