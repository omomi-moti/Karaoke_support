# feature/i-014-history 実装ログ

**日付**: 2026-03-22  
**対象**: [I-014] History 画面、`docs/v1_issues.md` L218–275（本 Issue ＋ I-014-A / B / C 分岐）

---

## 概要

履歴タブで **歌唱セッション一覧**（直近ウィンドウ・Intent フィルター・削除）を提供し、拡張として **セマンティックカラー（I-014-A）**、**並び替え（I-014-B）**、**履歴からの編集（I-014-C）** を実装した。  
アーキテクチャは **ViewModel + Repository**（`.cursorrules`）、一覧表示は **値型 `HistorySessionRowDisplayItem`** で SwiftData fault を避ける。

---

## [I-014] History 画面（本体）

| v1_issues 要件 | 実装の要点 |
|----------------|------------|
| 日時降順一覧（直近ウィンドウ） | `SessionRepository.fetchAll(limit:offset:)` → `HistoryViewModel` が `filter → sort` 後に値型へ写す |
| Intent フィルター | `HistoryFilterBarView` + `HistoryIntentFilter`（メモリ上 `filter`） |
| 曲名 V1 | `TrackDisplayTitle.primary(for:)`（`HistorySessionRowDisplayItem` 生成時に固定） |
| 行タップ | **I-014-C で** `NavigationLink` + リードスワイプ「編集」に接続（従来の「未接続」は解消） |
| スワイプ削除 | `HistoryViewModel.deleteSession` → `deleteRecordingSession`、世代 `loadGeneration` で競合回避 |

### 主なファイル

- `Sources/Presentation/History/List/HistoryListView.swift` — 一覧・フィルター・ソート UI・`NavigationLink` / スワイプ
- `Sources/Presentation/History/HistoryListContainerView.swift` — `NavigationStack(path:)`、編集先 `navigationDestination(for: UUID.self)`、保存後 `load()`、`editPath.removeLast()` は **`isEmpty` ガード付き**
- `Sources/Presentation/History/HistoryViewModel.swift` — `load` / `deleteSession`、`filter → sort`
- `Sources/Presentation/History/List/HistorySessionRowView.swift` / `HistorySessionRowDisplayItem.swift` — 行 UI・値スナップショット
- `Sources/Presentation/Root/RootView.swift` — 履歴タブは **外側 `NavigationStack` を外し**、スタックは `HistoryListContainerView` に集約（編集 push 用・二重スタック回避）

---

## [I-014-A] 色・テーマ（履歴画面）

- **`AppColor`**（セマンティック名）＋ **Asset Color Set** で背景グラデ・カード・スコア・バッジ・フィルターチップを集約。
- ダーク寄せ固定・コントラスト方針は **`docs/design/color_tokens_v1.md`** に記載。
- `AccentColor.colorset` と `AppAccentScore` の整合。

関連: `Sources/Presentation/Theme/AppColor.swift`、`Assets.xcassets` のセマンティックカラー。

---

## [I-014-B] ソート（日付・点数）

- **`HistorySortOrder`** — 日付新/古・点数高/低の 4 種。適用順は **`filter → sort`**（コード・コメントで明文化）。
- UI: **`HistorySortControlView`**（フィルター直下、メニュー形式 Picker）。VoiceOver は Picker に `accessibilityLabel` / `accessibilityValue`（HStack の `combine` は未使用）。
- V1 は **`fetchAll` 後のメモリ整列**。I-015 ページネーション時に DB 側 sort を検討可能。

主なファイル: `Sources/Presentation/History/Filters/HistorySortOrder.swift`, `Sources/Presentation/History/Filters/HistorySortControlView.swift`。

---

## [I-014-C] 履歴からの記録の更新（編集）

| 要件 | 実装 |
|------|------|
| 遷移 | `NavigationStack` + `NavigationLink(value: session.id)` + リードスワイプ「編集」 |
| 編集モード VM | `RecordingSheetViewModel` の `init(editingSession:)`、`editingSessionId` で `save()` が **`updateRecordingSession`** に分岐 |
| 新規 vs 更新 | 新規 → `saveNewRecordingSession`、編集 → `updateRecordingSession`（同一 id を `saveNew` に流さない） |
| 保存後 | `onSavedMoveToHistory` で `editPath` を pop（空ならスキップ）+ `HistoryViewModel.load()` |
| FR-011 | 保存失敗は既存のインラインエラー＋再試行。**編集画面のフェッチ失敗**はメッセージ＋**再試行**（`loadErrorMessage` クリア後 `buildViewModelIfNeeded()`）＋閉じる |

### Repository

- **`SessionRepositoryProtocol.fetchRecordingSession(uuid:)`** — 編集前に 1 件取得。
- **`SwiftDataSessionRepository`** — `#Predicate` で id 一致 1 件。
- **`PreviewSessionRepository`** — 固定 UUID のサンプル 3 件。**`fetchAll` は静的のため編集内容が一覧に反映されない**（ファイル先頭コメントで明示）。

### 記録シート

- **`RecordingDraft.performedAt`** — 新規・編集とも `SingingSession` に反映。
- **`RecordingSheetPerformedAtSection`** — `DatePicker`、カード幅は他セクションと揃える（`frame(maxWidth: .infinity)`、角丸 24）。
- **`TrackInputState(trackForEditingSession:)`** + **`init(mode:manualName:validationMessage:)`** — メンバーワイズ消失対策。
- 曲の差し替えは不可（Repository 制約）。手動曲は **無効化された TextField**、Spotify 系は **読み取り風テキスト**（`isTrackInputLockedForEdit` + `TrackInputSectionView.isDisabled`）。

### `RecordingSessionSeed`

- **`.editSession(sessionId: UUID)`** — `RecordingSheetContainerView` が `.task(id: seed)` で `fetchRecordingSession` → VM 構築。

---

## 本ブランチレビュー表（v1_issues L233–245）の現状

| 種別 | 内容 | 現状メモ |
|------|------|----------|
| 競合リスク | 削除と `load` の世代 | `loadGeneration` / `deleteSession` ガードで **対応済**（v1_issues 記載どおり） |
| UX / 初期表示 | VM 生成遅延 | `HistoryListContainerView` の `State(initialValue:)` で **対応済** |
| プレビュー制限 | プレビューで編集が一覧に出ない | `PreviewSessionRepository` コメントで **明示**。インメモリストアは未着手 |
| Repository | 直近 N 件 + メモリ filter | 仕様どおり。I-015 で **fetch 戦略の再検討**が負債候補 |
| 色・トークン | リテラル Color | **I-014-A で AppColor + Asset に寄せ済み**（当時の「未着手」は解消） |
| ソート | 日時のみ | **I-014-B で UI + メモリ整列を実装済み** |
| 履歴からの編集 | 新規のみ・行タップ未接続 | **I-014-C で解消**（`save()` 分岐・ナビ接続） |

---

## テスト（参照）

- `HistorySortOrderTests` / `HistoryViewModelSortTests` — ソートと filter→sort
- `RecordingSheetViewModelEditSaveTests` — 編集保存で `updateRecordingSession` が呼ばれること
- `HistoryViewModelSortTests` の `StubSessionRepository` — `fetchRecordingSession` をスタブ実装

---

## 残る負債・フォロー（任意）

- **I-015** — ページネーション時の **Repository 側 sort / filter** との整合
- **プレビュー** — 編集結果を一覧に反映する **簡易ストア**（必要なら）
- **編集ロード** — 再試行連打時の **同一 fetch 多重実行**は稀に起こりうる（致命ではない）。必要ならデバウンスや `isLoading` フラグ

---

## 仕様書との照合

| 参照 | ドキュメント |
|------|----------------|
| Issue 定義 | `docs/v1_issues.md` [I-014] および I-014-A / B / C |
| 非機能・エラー | `docs/raw_spec.md`（FR-011 再試行、VoiceOver 方針 等） |
| 色トークン | `docs/design/color_tokens_v1.md` |

以上。
