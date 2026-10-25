# feature/i-018-time-machine-display 実装ログ

**日付**: 2026-03-26  
**対象**: [I-018] タイムマシン表示（`docs/v1_issues.md` L317–326）

---

## 概要

**過去1ヶ月の歌唱回数ランキング**の取得・一覧・タップ遷移の本体は **[I-017]**（`IntentTabViewModel`・`TimeMachineRankingSheetView`・`fetchTimeMachineRanking()`）で実装済みである。本ログでは、**I-018 の「タイムマシン」シート**をワイヤーに沿った **STATS 風ヒーロー + TOP 5 行**に揃えるため、**共通化した UI コンポーネント**と **`IntentTabInsightStyle` のランキングシート用トークン**を追加した変更を記録する。

マイアンセム一覧（`MyAnthemRankingSheetView`）も同一のヒーロー・行コンポーネントを利用し、**インテントタブ内のランキングシートの見た目を統一**している。

---

## v1_issues タスク対応表（I-018）

| 要件 | 実装の要点 |
|------|------------|
| `fetchTimeMachineRanking()` で過去1ヶ月のランキングを取得 | **I-017** の `IntentTabViewModel.load()` → `InsightRepository.fetchTimeMachineRanking()`。 |
| 歌った回数降順でリスト表示 | **I-017** の `TimeMachineRankingSheetView` が `rankings` を **先頭5件**表示（`InsightRepository` の `fetchAll` 並びと整合）。 |
| V1 では曲名を一貫表示 | **`InsightTrackRowTitle.text`**（`InsightRankingSheetRowView` の `title` に渡す）。 |
| 曲タップで `SelectedTrack` → 記録シート | **I-017** の `onSelectTrack` → `SongsRootView` の `presentedRecordingRoute = .recording(...)`。 |

---

## 本変更で追加・更新したファイル（UI レイヤー）

### `IntentTabInsightStyle.swift`

- **ランキングシート**用の色トークンを追加。  
  - `rankingSheetBackground` … シート全体背景（極暗パープル）  
  - `rankingSheetHeroGradientTop` / `rankingSheetHeroGradientBottom` … ヒーローカードのグラデ  
  - `rankingSheetRowBackground` … ランキング行のカード面  

### `InsightRankingSheetHeroHeaderView.swift`（新規）

- シート上部の **STATS ラベル + タイトル + サブタイトル + SF Symbol** のヒーロー。  
- 背景は `IntentTabInsightStyle` のヒーローグラデを使用。  
- **タイムマシン**では `statsLabel: "STATS"`、`title: "直近1ヶ月の歌唱回数"`、`subtitle: "あなたの最新のトレンドをチェックしましょう"`、`systemImageName: "clock.fill"` を渡す。

### `InsightRankingSheetRowView.swift`（新規）

- **ランキング TOP 5** の1行。順位・曲名（`String`）・任意のアーティスト行・右側の値（「○回」等）・タップ。  
- 1位の強調色に `AppColor.accentScore` を使用。  
- `artistLine` は V1 では多く `nil`（`InsightTrackRowTitle` 由来のタイトルのみ）。

### `TimeMachineRankingSheetView.swift`

- 上記 **ヒーロー＋行**に差し替え。  
- 背景・ナビゲーションバーは `IntentTabInsightStyle.rankingSheetBackground` と整合。  
- 空状態は「まだデータがありません」。  
- 行タップは従来どおり `dismiss` 後に `onSelectTrack`（`Task { @MainActor in ... }`）。

---

## I-017 との関係

- **データ取得・ナビゲーション**は I-017 のまま。  
- **見た目の専用化**（STATS ヒーロー・行の切り出し・色トークン）は本ログ（I-018 の残差「文言・専用画面の切り出し」に相当）で扱った。

---

## テスト

- 本変更は **主に View の分割とスタイル**のため、**新規ユニットテストは未追加**。  
- 既存の **`IntentTabViewModelTests`** 等は I-017 のデータ経路を継続して検証する。

---

## 参照

- Issue 定義: `docs/v1_issues.md` [I-018]  
- 親実装ログ: `log/feature/i-017-intent-tab-ui/20260325_i017_intent_tab_ui_implementation.md`  
- 曲名表示: `InsightTrackRowTitle`  
- Repository: `InsightRepositoryProtocol.fetchTimeMachineRanking()`

以上。
