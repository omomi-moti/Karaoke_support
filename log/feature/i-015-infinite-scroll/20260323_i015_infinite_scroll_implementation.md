# feature/i-015-infinite-scroll 実装ログ

**日付**: 2026-03-23  
**最終更新**: 2026-03-22（コード再検証・並び替え注記・削除レースメモ）  
**対象**: [I-015] Infinite Scroll（`docs/v1_issues.md` L279–286）、履歴一覧のページング・メモリ方針・Intent 絞り込み

---

## 概要

履歴タブで **`fetchAll(limit: 20, offset:)` ベースのページネーション**（`offset = pageIndex * 20`、0-based）と、**リスト末尾付近での追加読み込み**、**表示行数の上限**、**初回／追加読み込みのインジケータ**を実装した。  
Intent フィルター時は SwiftData の `#Predicate` による Intent 絞り込みが **安定しない**（列挙比較・`rawValue` キーパス検証の制約）ため、**直近 `SessionRecentWindow.maxSessionCount` 件のウィンドウ**を取得し **メモリ上で Intent 一致に絞ったうえで `offset` / `limit` を適用**する。同一ウィンドウ内の **2 ページ目以降は Repository 内キャッシュをスライス**し、不要な `fetchAll` 繰り返しを避ける。

**本番・プレビュー共通**: スライス終端は `offset + limit` の **Int オーバーフロー**を避けるため `addingReportingOverflow` ベースの **`sliceEnd(offset:limit:count:)`** で計算（`SwiftDataSessionRepository` / `PreviewSessionRepository`）。

---

## v1_issues タスク対応表

| 要件 | 実装の要点 |
|------|------------|
| `fetchAll(limit: 20, offset)`・`offset = pageIndex * 20` | `HistoryViewModel` の `pageSize = 20`、`fetchPage(for:page:)` で `offset = page * pageSize`。**「すべて」**は `SessionRepository.fetchAll(limit:offset:)` をそのまま使用。 |
| スクロール末尾で追加読み込み | `HistoryListView` の各行に `.task(id: session.id)` を付け、`HistoryViewModel.loadNextPageIfNeeded(currentItemID:)` を呼ぶ。**末尾から 5 行以内**（`prefetchThreshold`）で次ページを要求。`shouldPrefetch` は **末尾 `prefetchThreshold` 件のスライスに `itemID` が含まれるか**だけ判定（全件 `firstIndex` しない。厳密なスクロール座標ではなく **出現ベースのプリフェッチ**）。 |
| 大量データでもメモリ抑制 | 一覧は常に **`HistorySessionRowDisplayItem`（値型）のみ**保持。さらに **`maxDisplayedSessionRows = 500`** を超えたら先頭 500 件に切り詰め、`hasMorePages = false` で追加フェッチを止める。Intent 側は **ウィンドウキャッシュ**で DB 読みの重複を抑える。 |
| ローディングインジケータ | 初回: `isLoading && sessions.isEmpty` で全画面 `ProgressView`。追加: `isLoadingNextPage` 時に `List` 末尾に `ProgressView`。 |

---

## レイヤー別の責務

### `HistoryViewModel`

- **状態**: `sessions`（表示スナップショット）、`currentPage`、`hasMorePages`、`isLoading`、`isLoadingNextPage`、`loadErrorMessage`、`pageSize`、`prefetchThreshold`、`maxDisplayedSessionRows`、`loadGeneration`（競合回避）。
- **初回**: `load()` → `loadInitial()` → `fetchPage(..., page: 0)` → `applyInitialPage`。
- **追加**: `loadNextPageIfNeeded` → `fetchPage(..., page: currentPage)`（初回適用後、`currentPage` は「次に取るページ番号」。空でなければ初回後は 1 からスタートし、各 `appendPage` で +1）。
- **ソート**: `filter` 適用後の取得結果を `sortOrder` で整列。**取得済み範囲のみ**再ソート（`applySortToLoadedSessions`）。
- **上限**: `enforceDisplayedSessionCap()` — ソート済み配列の **先頭 `maxDisplayedSessionRows` 件**を残し、末尾を捨てる（現在のソート順で「一覧の下側」を落とす）。
- **エラー文言**: 追加読み込み失敗時に `loadErrorMessage` をセットするが、**その後の追加読み込みが成功したタイミング**（`appendPage` 直前）で `loadErrorMessage = nil` し、エラー表示が残り続けないようにする。
- **`shouldPrefetch`**: `sessions` が空でなければ `startIndex = max(0, count - prefetchThreshold)` とし、`sessions[startIndex...].contains { $0.id == itemID }` で末尾ブロックに該当行があるかだけ見る。

### `HistoryListView`

- `viewModel.filter` 変更時に `.task(id:)` で `load()`（従来どおり）。
- 各行 `.task(id: session.id)` で末尾付近なら `loadNextPageIfNeeded`。

### `SwiftDataSessionRepository`

- **`fetchAll(limit:offset:)`**: `performedAt` 降順の `FetchDescriptor` に `fetchLimit` / `fetchOffset`。`limit` / `offset` は非負でなければ `invalidParameter`。
- **`fetchByIntent(_:limit:offset:)`**:
  - **データ範囲**: グローバル全期間の Intent 一覧ではなく、**直近 `SessionRecentWindow.maxSessionCount` 件**のウィンドウ上で `filter { $0.intent == intent }` した配列に対するスライス。
  - **`offset == 0`**: 常に `fetchAll(maxSessionCount, 0)` でウィンドウを取り直し、`intentFilterCache = (intent, filtered)` を更新。
  - **`offset > 0`**: キャッシュの `intent` が一致すれば **同じ `filtered` 配列をスライス**のみ。不一致・キャッシュなしはウィンドウを再構築。
  - **スライス**: `start` / `end` は `sliceEnd(offset:limit:count:)` で `offset + limit` のオーバーフローを避ける。
  - **無効化**: `saveNewRecordingSession` / `updateRecordingSession` / `deleteRecordingSession` 成功後に `invalidateIntentFilterCache()`（データ変更後に古い絞り込みを使わない）。

### `SessionRepositoryProtocol`

- `fetchByIntent(_:limit:offset:)` の **データ範囲と SwiftData の制約**をドキュメントコメントに明記。
- **`fetchByIntent(_ intent: Intent)`**（ページングなし）はプロトコル拡張で **`fetchByIntent(intent, limit: SessionRecentWindow.maxSessionCount, offset: 0)`** に委譲。

### `PreviewSessionRepository`

- 静的サンプル配列から `intent` で絞り、`offset` / `limit` でスライス（プレビュー専用）。
- **`fetchAll` / `fetchByIntent`**: `limit` / `offset` 非負チェック（`invalidParameter`）。終端は **`sliceEnd`**（本番と同様の加算安全）。

---

## SwiftData / Intent で Predicate を使わない理由（要約）

- `#Predicate` に **外側からキャプチャした `Intent`** や **`Intent.shout` 形式**を入れると、マクロ展開・実行時検証で失敗することがある。
- **`intent.rawValue`** を述語に含めると、`SingingSession.intent.rawValue` が **永続キーパスとして無効**となり実行時に fatal になり得る。
- よって **ウィンドウ `fetchAll` + メモリ `filter`** に落ち着いた。

将来、**永続化用の String 列**などで DB 側絞り込みに寄せる余地あり（マイグレーション要検討）。

---

## テスト

- `HistoryViewModelPaginationTests` — 「すべて」／Intent スタブで `offset` の連続、`loadNextPageIfNeeded` が末尾以外では追加フェッチしないこと。**`testPagination_StopsAtDisplayedSessionCap`** で **500 件超後の `prefix`・`hasMorePages == false`・上限後の追加フェッチなし**を検証。
- `SwiftDataSessionRepositoryFetchByIntentTests` — 並び・ページング（インメモリ SwiftData）。
- `HistoryViewModelSortTests` / `RecordingSheetViewModelEditSaveTests` 等 — `StubSessionRepository` が `fetchByIntent(limit:offset:)` を実装。

---

## 後から整えるとよいこと（仕様・UX）

無限スクロールの **MVP としては完了**しているが、次の点は **ユーザー期待とズレる可能性**があるため、リリース後に優先度を付けて検討するとよい。

### 並び替え（点数・日付の古い順）とページングの関係

- **現状**: `fetchAll` / `fetchByIntent` はいずれも **歌唱日時 `performedAt` の降順**でページを切っている。一方、履歴画面の `HistorySortOrder`（点数の高い順・低い順・日付の古い順など）は、**いまメモリに載っている行だけ**を並べ替えている。
- **結果**: 「点数が一番高いセッションが常に一覧の先頭に来る」「日付の古い順で全世界を正しく辿る」といった **グローバルな順序**は保証されない。追加読み込みを重ねるほど、**日付順で取った塊を画面上で並べ替えた結果**になる。
- **直すかどうか**: 不具合（クラッシュ）ではなく **仕様の幅**の問題。  
  - **手早い改善**: ソート変更時に説明文を足す／「表示中の範囲での並び」であることを明示する／ページングと両立しないソートでは「すべて読み込む」かソートを制限する、など。  
  - **根本対応**: Repository または `FetchDescriptor` 側で **並びキーに合わせた取得**（スキーマ・インデックス・ソートパラメータの追加）を検討する。工数は大きめ。
- **I-014-B** の方針どおり、**V1 はメモリ上の `filter → sort`** とし、**I-015 以降で DB 側 sort とページングを両立させる**のは別イシューでよい。

### その他

- **Intent の「全期間」一覧**が必要なら、ウィンドウではなく DB 上で Intent を表現できるようスキーマを見直す、など（上記「残る負債」と同じ系統）。

---

## 残る負債・フォロー（任意）

- **並び替えとページング**の詳細は上記「**後から整えるとよいこと**」を参照（重複するためここでは短く：DB は常に日付降順でページング、UI の `sortOrder` は **読み込み済み行の範囲**に対してのみグローバル順と一致しうる）。
- **Intent 一覧の「全期間」**を DB でページングしたい場合は、スキーマ／Predicate 可能な表現の見直し。
- **表示 500 件打ち切り**後に「さらに見る」が必要なら、別 UX（リセット・検索）を検討。
- **スクロール位置ベース**のプリフェッチ（`onScrollGeometryChange` 等）は OS 要件と合わせて検討可能。
- **削除 × 追加読み込みのレース（未対応・レア）**: `loadNextPageIfNeeded` は `defer` で `myGeneration == loadGeneration` のときだけ `isLoadingNextPage = false` に戻す。`deleteSession` が `loadGeneration` を先に進めると、進行中の追加読み込み完了時に世代が一致せず **`isLoadingNextPage` が `true` のまま残り得る**。通常は削除成功後の `load()` → `loadInitial` で `isLoadingNextPage` がクリアされる。**追加読み込み中に削除し、削除が失敗して `load()` しない経路**（一覧をスナップショットに戻して `return`）と重なると、末尾 `ProgressView` が止まらない／次の追加読み込みが `guard !isLoadingNextPage` で止まる可能性がある。対策案: `deleteSession` で `loadGeneration` を進めるタイミングで `isLoadingNextPage = false` を明示する等。優先度は低く、再現も限定的。

---

## 参照

- Issue 定義: `docs/v1_issues.md` [I-015]
- セッション直近ウィンドウ: `Sources/Domain/Repositories/SessionRecentWindow.swift`
- Repository 契約: `Sources/Domain/Repositories/SessionRepositoryProtocol.swift`

以上。
