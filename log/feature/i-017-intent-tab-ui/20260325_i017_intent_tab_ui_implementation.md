# feature/i-017-intent-tab-ui 実装ログ

**日付**: 2026-03-25  
**対象**: [I-017] インテントタブUI（`docs/v1_issues.md` L302–309）

---

## 概要

選曲タブの **「インテント」セグメント**に、インサイト用の **ヒーローUI**（ヘッダー・タイムマシン・マイアンセムの2カード・今月統計）を配置した。データは **`InsightRepositoryProtocol`**（`fetchTimeMachineRanking` / `fetchMyAnthemRankings`）から **`IntentTabViewModel`** が取得する。歌唱セッションが **0 件**のときは I-016 の **`SingingEmptyStateView`** を表示し、手動記録への導線は **`navigateToManualRecording`**（`SongsRootView` が `@Environment` で受け取り注入）とする。

ランキングの **一覧と曲タップ**はシート（`TimeMachineRankingSheetView` / `MyAnthemRankingSheetView`）で実装し、確定した **`SelectedTrack`** は親の `NavigationPath` に **`SongsRecordingRoute.recording(SelectedTrack)`** として積む（選曲タブ内の既存 `NavigationStack` 方針と整合）。

---

## v1_issues タスク対応表

| 要件 | 実装の要点 |
|------|------------|
| タイムマシン表示領域 | `TimeMachineInsightCardView`（紫系グラデ・NEW ANALYTICS・「振り返る」）。`IntentTabInsightStyle` で色トークンを集約。 |
| マイアンセム表示領域 | `MyAnthemInsightCardView`（インディゴ系グラデ・感情アイコン・「AIが選曲しました」・「聴く」）。 |
| InsightRepository ViewModel | `IntentTabViewModel` が `insightRepository` / `sessionRepository` を DI。`IntentTabContainerView` が `State(initialValue:)` で生成し、`onAppear` で `load()`。 |
| 歌唱0件時 Empty State | `load()` 先頭で `fetchAll(limit: 1, offset: 0)` が空なら `hasSingingData = false` → `IntentTabInsightView` が `SingingEmptyStateView` を表示。 |

---

## レイヤー別の責務

### `IntentTabViewModel`（`Presentation/Songs`）

- `@Observable` / `@MainActor`。  
- **`load()`**: セッション有無 → 無ければランキング取得をスキップ。あれば `fetchTimeMachineRanking` と `fetchMyAnthemRankings(period: .threeMonths)` を並列取得。  
- **`computeMonthStats()`**: `fetchAll(limit:offset:)` をページングし、**半開区間** `[monthStart, nextMonthStart)` に入る `performedAt` のセッションだけで **今月の総曲数** と **平均スコア** を集計。  
- 初回表示フラッシュ防止のため **`init` 完了時点で `isLoading = true`**。  
- 失敗時は `loadErrorMessage` を表示し、`IntentTabInsightView` から「再試行」で `load()` 再実行。

### `IntentTabContainerView`

- `InsightRepository` / `SessionRepository` を **init で受け取り** `IntentTabViewModel` を `@State` で保持（Environment では `init` で参照できないため、親が `SongsRootView` から注入）。  
- **`onSelectTrack`**: シートで選んだ `SelectedTrack` を親へ渡す（`path.append`）。  
- **`onNavigateToManualRecording`**: Empty State のボタン用。

### `IntentTabInsightView`

- ローディング / エラー / Empty / 通常（`ScrollView` + ヘッダー + 2カード + `IntentTabMonthlyStatsRowView`）の分岐。  
- `.sheet` でランキング一覧を表示。

### シート（`TimeMachineRankingSheetView` / `MyAnthemRankingSheetView`）

- 行タップで `makeSelectedTrack()` → `dismiss` 後に `onSelectTrack`（`DispatchQueue.main.async` で親の `path` 更新と競合しにくくする）。  
- マイアンセムは **Intent ごとに Section**（`MyAnthemRanking` を `ForEach`、各 `byCount` の先頭5件）。

### ドメイン補助

- **`InsightTrackRowTitle`**: 曲名表示（手入力名を優先）。  
- **`InsightTrackCountRanking` / `InsightTrackScoreRanking`**: `makeSelectedTrack()` で `SelectedTrack?` を生成。

### `SongsRootView`

- `@Environment(\.insightRepository)` / `sessionRepository` / `navigateToManualRecording` を取得。  
- インテントセグメントで `IntentTabContainerView` を表示し、`onSelectTrack` で `path.append(SongsRecordingRoute.recording(selected))`。  
- **プレビュー**で各 Environment を明示的に注入。

---

## 表示・ナビゲーションの流れ

1. ユーザーがインテントタブを開く → `onAppear` で `load()`。  
2. **データあり** → ヘッダー・2カード・統計を表示。「振り返る」「聴く」でシート。  
3. シートで曲を選択 → シートを閉じたあと **記録フロー**へ push。  
4. **データなし** → `SingingEmptyStateView` → タップで `navigateToManualRecording`（選曲タブへ切替 + 手動記録ルート。I-016 と同じ Environment）。

---

## テスト

- **`IntentTabViewModelTests`**: `PreviewInsightRepository` + `PreviewSessionRepository` で `load()` 後に `hasSingingData`・ランキング件数などを検証するスモークテスト。

---

## 月次統計（`computeMonthStats`）の注意 — パフォーマンスと将来の最適化

### 現状（V1）

- `SessionRepository.fetchAll(limit:offset:)` を **500 件ずつ**繰り返し、**全件走査に近い**形で集計する。セッション総数が増えるほど **`load()` 内の読み取り回数**が増える。
- 本番の **`SwiftDataSessionRepository`** は `performedAt` **降順**で返す（`SortDescriptor`）。一方 **`SessionRepositoryProtocol`** にはソート順の明記がない。

### 検討されうる最適化（未実装・優先度は低〜中）

- **降順前提**で、先頭から走査し **`performedAt < monthStart` が初めて出た時点**でページングを打ち切る、と **今月より古いセッションが現れた時点で以降のページは不要**になるため、過去データが多い場合に **読み取りを早く終えられる**可能性がある。
- 入れる場合の前提: **プロトコルまたはドキュメントで `fetchAll` の並びを保証**する／**モック・テスト用スタブも `performedAt` 降順に揃える**（並びがバラバラだと打ち切りは誤集計になる）。
- **より根本的な対策**: `SessionRepository` に **期間指定の件数・平均**や **`#Predicate` による集計**を追加し、ViewModel ではページングしない。これは **V2 や別 Issue** で検討しうる。
- **優先度**: 体感・計測で **ボトルネックが出るまで後回し（P2〜P3）** でよいことが多い。先に **半開区間による定義の正しさ**（`[monthStart, nextMonthStart)`）を優先した。

---

## I-018 との関係

- **I-017** ではタイムマシンを **カード + シート一覧**として実装済み（`fetchTimeMachineRanking`・降順表示・`SelectedTrack` 遷移）。  
- **`docs/v1_issues.md` [I-018]** に残っている「専用リスト画面」「`userEnteredName ?? "不明"`」などは、文言・画面分割の追従タスクとして切り出せる（本実装は `InsightTrackRowTitle` でフォールバック文言を統一）。

---

## 参照

- Issue 定義: `docs/v1_issues.md` [I-017]  
- Repository: `InsightRepositoryProtocol`, `SwiftDataInsightRepository`  
- Empty State: `SingingEmptyStateView`, `ManualRecordingNavigationEnvironment`  
- 選曲ルート: `SongsRecordingRoute`

以上。
