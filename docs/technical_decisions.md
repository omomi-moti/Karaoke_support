# 技術的な工夫と解決策

## 技術的な工夫（Highlights）

保存フロー・冪等性の全体像は [architecture.md](architecture.md) の「歌唱記録の保存フロー」を参照。以下は代表的な実装判断のハイライトである。

### 1. Spotify API 規約と設計の両立

Spotify API 規約でメタデータ（曲名・アーティスト名・アートワーク）の永続保存が禁止されている。この制約に対し、**Track エンティティに `spotifyTrackId` のみを保持し、表示用メタデータは V2 で actor ベースのインメモリ TTL キャッシュ（24h）から取得する設計**を先行して定義した。

V1 では `userEnteredName`（ユーザー生成データ＝永続化可）で曲名表示を行い、Spotify 未連携でもコア体験を完結させた。Track の convenience init を `spotifyTrackId` 用（`precondition(!spotifyTrackId.isEmpty)`）と `userEnteredName` 用に分離し、private init で代入ロジックを単一化することで、将来の Spotify 連携時に Track の型安全性を壊さず拡張できるようにした。

### 2. `loadGeneration` カウンタによる非同期競合排除

`HistoryViewModel` では、フィルター変更や削除処理が非同期完了と交差したとき、古いレスポンスが `sessions` を上書きする問題がある。`Task.cancel()` は cancel が非同期で伝播するため「cancel 前に完了した古い fetch が先に sessions を書き換える」ケースを完全には防げない。

そこで `loadGeneration` カウンタを導入し、**発行世代と完了世代が一致する場合のみ `sessions` を書き換える**パターンを採用した。コストは Int の加算と比較のみ（O(1)）で、`loadInitial` / `loadNextPageIfNeeded` / `deleteSession` のすべてで統一的に競合を排除できる。

### 3. 歌唱記録の 1 シート統合と NavigationStack 設計

仕様上は Intent 選択画面・歌唱記録入力画面が別画面（S-004/S-005）だったが、**UX 改善のため 1 枚の Recording Sheet に統合**し、**曲名入力 → スコア → Intent → 歌唱日時 → メモ → 保存**を途切れなく完結できるようにした。

`NavigationStack` の push で歌唱記録を出すと、保存後に `NavigationPath` を空にして pop する際にルートビュー（インテント一覧）が一瞬露出する「チラつき」が発生する。`.sheet(item:)` によるモーダル表示に切り替えることで、保存後は `presentedRecordingRoute = nil`（シート解除）+ `selectedTab = .history` のみで遷移が完結する。

### 4. History の値型スナップショットパターン

`HistoryViewModel` は SwiftData インスタンスを直接保持せず、`HistorySessionRowDisplayItem`（値型）にマッピングして保持。これにより:

- **楽観的 UI 更新**: 削除時に先にスナップショットから除外し、DB 削除失敗時はスナップショットを復元。ユーザーには即座に反映される
- **メモリ制御**: 歌唱回数が多いユーザーで 2000〜3000 件に達する想定に対し、一覧保持の上限を 500 件に設定。値型のため SwiftData の fault を踏まない
- **ソート・フィルター**: 値型配列に対するメモリ上の操作で完結し、再フェッチが不要

### 5. 冪等性の二重保証

カラオケボックス（地下）の不安定な通信環境を前提に、二重送信を 2 段階で防止:

- **UI 層**: 保存ボタン即時非活性化（`isSaving` フラグ）+ ProgressView + ユーザーインタラクションブロック
- **データ層**: クライアント生成 UUID を Idempotency Key として `exists(uuid)` チェック → 既存なら insert / `singCount` 加算をスキップして成功扱い

UI 層のみの制御は「ボタン tap → 非活性化」の間にタッチイベントが2回発火するエッジケースに対応できないため、データ層の冪等保証が必須。

### 6. テストにおける DI の活用

ユニットテスト（14 ファイル）では Repository Protocol の DI が実際に機能している:

- `SwiftDataSessionRepository*Tests`（4 ファイル）: in-memory `ModelContainer` で SwiftData の実インスタンスを生成し、冪等性・削除・更新・Intent フィルターをテスト
- `HistoryViewModel*Tests`（3 ファイル）: Mock Repository を ViewModel init に注入し、ページネーション・ソート・loadGeneration の競合を検証
- `RecordingSheetViewModelEditSaveTests`: 新規作成と編集の分岐を Protocol 差し替えで検証

---

## 技術的な壁と解決策

### 1. SwiftData `#Predicate` × enum の不安定性

`#Predicate<SingingSession> { $0.intent == .shout }` はコンパイルが通るが、iOS 17.0〜17.2 の実機で `NSPredicateError` に類する実行時エラーが発生するケースを確認した。RawValue（String）比較への書き換えも試みたが、`#Predicate` の型推論と衝突して安定しなかった。

**解決策**: `fetchByIntent` を直近 `SessionRecentWindow.maxSessionCount` 件の `fetchAll` 後にメモリ上で `filter { $0.intent == intent }` する方式に切り替え。`intentFilterCache` で同一 Intent のページ追加時に再フェッチを抑制した。この判断はコード内コメントに理由を記載している。

### 2. NavigationStack と .sheet の共存バグ

選曲タブで `NavigationStack` の `navigationDestination` と `.sheet` を同時に使うと、sheet dismiss 後に `NavigationStack` の状態が壊れ、push 遷移が効かなくなるケースが iOS 17.0 で発生した。原因は `NavigationPath` と sheet の `isPresented` が同一 View 更新サイクルで競合するため。

**解決策**: 選曲タブは **NavigationStack（ルートのみ・push なし）+ `.sheet(item:)` のみ**に統一。歌唱記録は push せずシートで表示し、保存後は `presentedRecordingRoute = nil` + `selectedTab = .history` で遷移する。この設計判断は `docs/v1_navigation_songs_recording.md` に経緯を記録した。

### 3. 仕様書群の矛盾管理

5 ファイル以上の仕様書（raw_spec → spec.md → basic_design → detailed_design → issues）間で、Spotify メタデータのキャッシュ戦略について「UserDefaults」と「インメモリ 24h キャッシュ」で矛盾が発生した。`cross_check_report.md` で矛盾を手動棚卸しし、全ドキュメントを「インメモリ一時キャッシュ・永続化禁止」に揃えた。`v1_issues.md` を V1 の Single Source of Truth とする運用で再発を防止。
