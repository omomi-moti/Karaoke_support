# feature/i-015-infinite-scroll 実装ログ

**日付**: 2026-03-23  
**対象**: [I-015] Infinite Scroll（`docs/v1_issues.md` L279–286）、履歴一覧のページング・メモリ方針・Intent 絞り込み

---

## 概要

履歴タブで **`fetchAll(limit: 20, offset:)` ベースのページネーション**（`offset = pageIndex * 20`、0-based）と、**リスト末尾付近での追加読み込み**、**表示行数の上限**、**初回／追加読み込みのインジケータ**を実装した。  
Intent フィルター時は SwiftData の `#Predicate` による Intent 絞り込みが **安定しない**（列挙比較・`rawValue` キーパス検証の制約）ため、**直近 `SessionRecentWindow.maxSessionCount` 件のウィンドウ**を取得し **メモリ上で Intent 一致に絞ったうえで `offset` / `limit` を適用**する。同一ウィンドウ内の **2 ページ目以降は Repository 内キャッシュをスライス**し、不要な `fetchAll` 繰り返しを避ける。

---

## v1_issues タスク対応表

| 要件 | 実装の要点 |
|------|------------|
| `fetchAll(limit: 20, offset)`・`offset = pageIndex * 20` | `HistoryViewModel` の `pageSize = 20`、`fetchPage(for:page:)` で `offset = page * pageSize`。**「すべて」**は `SessionRepository.fetchAll(limit:offset:)` をそのまま使用。 |
| スクロール末尾で追加読み込み | `HistoryListView` の各行に `.task(id: session.id)` を付け、`HistoryViewModel.loadNextPageIfNeeded(currentItemID:)` を呼ぶ。**末尾から 5 行以内**（`prefetchThreshold`）で次ページを要求（厳密なスクロール座標ではなく **出現ベースのプリフェッチ**）。 |
| 大量データでもメモリ抑制 | 一覧は常に **`HistorySessionRowDisplayItem`（値型）のみ**保持。さらに **`maxDisplayedSessionRows = 500`** を超えたら先頭 500 件に切り詰め、`hasMorePages = false` で追加フェッチを止める。Intent 側は **ウィンドウキャッシュ**で DB 読みの重複を抑える。 |
| ローディングインジケータ | 初回: `isLoading && sessions.isEmpty` で全画面 `ProgressView`。追加: `isLoadingNextPage` 時に `List` 末尾に `ProgressView`。 |

---

## レイヤー別の責務

### `HistoryViewModel`

- **状態**: `sessions`（表示スナップショット）、`currentPage`、`hasMorePages`、`isLoading`、`isLoadingNextPage`、`pageSize`、`prefetchThreshold`、`maxDisplayedSessionRows`、`loadGeneration`（競合回避）。
- **初回**: `loadInitial()` → `fetchPage(..., page: 0)` → `applyInitialPage`。
- **追加**: `loadNextPageIfNeeded` → `fetchPage(..., page: currentPage)`（`currentPage` は直前までに読み終えた **次の** ページ番号としてインクリメント済み。初回後は 1 から次ページ）。
- **ソート**: `filter` 適用後の取得結果を `sortOrder` で整列。**取得済み範囲のみ**再ソート（`applySortToLoadedSessions`）。
- **上限**: `enforceDisplayedSessionCap()` — ソート済み配列の **先頭 `maxDisplayedSessionRows` 件**を残し、末尾を捨てる（現在のソート順で「一覧の上側」を優先）。

### `HistoryListView`

- `viewModel.filter` 変更時に `.task(id:)` で `load()`（従来どおり）。
- 各行 `.task(id: session.id)` で末尾付近なら `loadNextPageIfNeeded`。

### `SwiftDataSessionRepository`

- **`fetchAll(limit:offset:)`**: `performedAt` 降順の `FetchDescriptor` に `fetchLimit` / `fetchOffset`（I-003 と同じ）。
- **`fetchByIntent(limit:offset:)`**:
  - **データ範囲**: グローバル全期間の Intent 一覧ではなく、**直近 `SessionRecentWindow.maxSessionCount` 件**のウィンドウ上で `filter { $0.intent == intent }` した配列に対するスライス。
  - **`offset == 0`**: 常に `fetchAll(maxSessionCount, 0)` でウィンドウを取り直し、`intentFilterCache = (intent, filtered)` を更新。
  - **`offset > 0`**: キャッシュの `intent` が一致すれば **同じ `filtered` 配列をスライス**のみ。不一致・キャッシュなしはウィンドウを再構築。
  - **無効化**: `saveNewRecordingSession` / `updateRecordingSession` / `deleteRecordingSession` 成功後に `invalidateIntentFilterCache()`（データ変更後に古い絞り込みを使わない）。

### `SessionRepositoryProtocol`

- `fetchByIntent(_:limit:offset:)` の **データ範囲と SwiftData の制約**をドキュメントコメントに明記。

### `PreviewSessionRepository`

- 静的サンプル配列から `intent` で絞り、`offset` / `limit` でスライス（プレビュー専用）。

---

## SwiftData / Intent で Predicate を使わない理由（要約）

- `#Predicate` に **外側からキャプチャした `Intent`** や **`Intent.shout` 形式**を入れると、マクロ展開・実行時検証で失敗することがある。
- **`intent.rawValue`** を述語に含めると、`SingingSession.intent.rawValue` が **永続キーパスとして無効**となり実行時に fatal になり得る。
- よって **ウィンドウ `fetchAll` + メモリ `filter`** に落ち着いた。

将来、**永続化用の String 列**などで DB 側絞り込みに寄せる余地あり（マイグレーション要検討）。

---

## テスト

- `HistoryViewModelPaginationTests` — 「すべて」／Intent スタブで `offset` 0 と 20 の呼び出し、末尾以外では追加読み込みしないこと。
- `SwiftDataSessionRepositoryFetchByIntentTests` — 並び・ページング（インメモリ SwiftData）。
- `HistoryViewModelSortTests` — `StubSessionRepository` が `fetchByIntent(limit:offset:)` を実装。

---

## 残る負債・フォロー（任意）

- **Intent 一覧の「全期間」**を DB でページングしたい場合は、スキーマ／Predicate 可能な表現の見直し。
- **表示 500 件打ち切り**後に「さらに見る」が必要なら、別 UX（リセット・検索）を検討。
- **スクロール位置ベース**のプリフェッチ（`onScrollGeometryChange` 等）は OS 要件と合わせて検討可能。

---

## 参照

- Issue 定義: `docs/v1_issues.md` [I-015]
- セッション直近ウィンドウ: `Sources/Domain/Repositories/SessionRecentWindow.swift`
- Repository 契約: `Sources/Domain/Repositories/SessionRepositoryProtocol.swift`

以上。
