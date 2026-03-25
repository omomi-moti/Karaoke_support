# feature/i-016-empty-state 実装ログ

**日付**: 2026-03-22  
**対象**: [I-016] Empty State（歌唱0件）（`docs/v1_issues.md` L290–296）

---

## 概要

歌唱セッションが **まだ 1 件も無い**とき、履歴タブでユーザーに次の行動を促す。**文言は `docs/v1_issues.md` [I-016] の本文どおり** `SingingEmptyStateCopy` に集約し、UI は **`SingingEmptyStateView`** に分離（I-017 のインテントタブ等で再利用可能）。

履歴から **手動で曲名を入力して記録**へ進むには、選曲タブの `NavigationStack` に載せる必要がある（I-013 の方針: 二重スタック回避）。そのため **`EnvironmentValues.navigateToManualRecording`**（App 層の `EnvironmentKey`）で **`RootView` が選曲タブ選択 + `SongsRootView` へ外部トリガー**を渡し、**`SongsRecordingRoute.manualRecording`** を `NavigationPath` に積む。

---

## v1_issues タスク対応表

| 要件 | 実装の要点 |
|------|------------|
| 「まず1曲歌ってみよう！」 | `SingingEmptyStateCopy.headline`。履歴 **`HistoryIntentFilter.all`** かつ一覧空・かつ初回ローディングでないとき `SingingEmptyStateView` を表示。 |
| 「手動で曲名を入力して歌う」導線 | `SingingEmptyStateCopy.manualEntryButtonTitle` の **Button**。アクションは `navigateToManualRecording`（no-arg クロージャ）。 |
| 再利用可能なコンポーネント | `SingingEmptyStateView` + `SingingEmptyStateCopy`。I-017 は同コンポーネントを差し込む想定（本ログ時点では選曲インテントセグメントは従来のプレースホルダーのまま）。 |

---

## レイヤー別の責務

### `SingingEmptyStateCopy`（`Presentation/Common`）

- I-016 の **固定文言のみ**（`headline` / `manualEntryButtonTitle`）。  
- **`SingingEmptyStateCopyTests`** で v1_issues と一致することを検証。

### `SingingEmptyStateView`（`Presentation/Common`）

- アイコン・見出し・ボタン（`borderedProminent`、ピンク系 `tint`）。  
- **`onManualEntryTap`** は呼び出し側が注入（履歴では `navigateToManualRecording`）。

### `ManualRecordingNavigationEnvironment`（`App`）

- `EnvironmentValues.navigateToManualRecording: () -> Void`。  
- **default は空のクロージャ**（プレビュー等で未注入でもクラッシュしない）。  
- `.cursorrules` に合わせ **EnvironmentKey は App 層**に配置。

### `RootView`

- `@State manualRecordingNavigationTick: Int` を **`SongsRootView` に `Binding` で渡す**。  
- `TabView` に `.environment(\.navigateToManualRecording) { ... }` を付与:  
  - `selectedTab = .songs`  
  - `manualRecordingNavigationTick += 1`  
- これにより **履歴配下の `HistoryListView`** も同じ Environment を継承する。

### `SongsRootView`

- `manualRecordingNavigationTick` の **`onChange`**: `newValue > 0` のとき  
  - `path = NavigationPath()`（履歴から来たときにスタックを汚さない）  
  - `path.append(SongsRecordingRoute.manualRecording)`  
- 既存の **「記録を追加」** ツールバーは従来どおり `path.append(.manualRecording)`。

### `HistoryListView`

- `@Environment(\.navigateToManualRecording)`。  
- **空表示の分岐**:  
  - `isLoading && sessions.isEmpty` → `ProgressView`（従来どおり）。  
  - それ以外で `sessions.isEmpty` → `emptyState`。  
- **`emptyState`**:  
  - **`.all`** → `SingingEmptyStateView(onManualEntryTap: navigateToManualRecording)`。  
  - **`.intent`** → 従来の「直近の記録に該当がありません」文言（**Intent だけ絞り込んで 0 件**は「全件 0 件」とは限らないため、I-016 のメイン文言は使わない）。

---

## 表示条件の整理（仕様）

| 状態 | 表示 |
|------|------|
| 初回読み込み中・一覧空 | `ProgressView` |
| 読み込み完了・「すべて」・0 件 | `SingingEmptyStateView`（I-016） |
| 読み込み完了・Intent 絞り込み・0 件 | 従来の Intent 用空メッセージ |

---

## テスト

- `SingingEmptyStateCopyTests` — `headline` / `manualEntryButtonTitle` が v1_issues と一致。

---

## フォロー（任意）

- **I-017**: インテントタブ本体で歌唱 0 件のとき **`SingingEmptyStateView`** を組み込む（本 Issue のテストは文言のみ）。  
- **`docs/issues_with_tasks.md`** の I-016 が未チェックのままなら、`v1_issues.md` と揃える。

---

## 参照

- Issue 定義: `docs/v1_issues.md` [I-016]
- 選曲ルート: `Sources/Presentation/Songs/SongsRecordingRoute.swift`
- 手動記録シート: `RecordingSheetContainerView` + `seed: .mode(.manual)`

以上。
