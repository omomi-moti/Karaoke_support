# feature/i-008-i-012-i-009-i-010 実装ログ（Recording Sheet UI）

**日付**: 2026-03-21  
**対象**: [I-012] 手動曲名入力 / [I-008] Intent選択 / [I-009] 歌唱記録入力 / [I-010] 二重送信防止（UI層）

**参照 Issue**: [`docs/v1_issues.md`](../../../docs/v1_issues.md)（該当セクション）

---

## 概要

独立画面ではなく **Recording Sheet 1 枚**に、手動曲名（I-012）・Intent 3 択（I-008）・スコア・メモ・保存（I-009）を集約。保存中の二重操作抑止（I-010）は同一シート内のオーバーレイと `isSaving` で実現。データ層の冪等性（I-011）は別ログ [`../i-011-data-idempotency/20260321_i011_implementation.md`](../i-011-data-idempotency/20260321_i011_implementation.md) を参照。

---

## [I-012] 手動曲名入力画面（シート内）

### 実装内容

| タスク | 実装の所在・要点 |
|--------|------------------|
| 曲名用 TextField | `TrackInputSectionView` — 手動モード時 `TextField("曲名", text: $state.manualName)`。 |
| 空文字で保存しない・バリデーション | `RecordingSheetViewModel.validate()` — `TrackResolver.resolveSelectedTrack` が `emptyManualName` のとき `trackState.validationMessage = "曲名を入力してください"`。 |
| オフライン時メッセージ（ブロックしない） | `RecordingSheetContentView` — `@Environment(\.networkMonitor)` で `!networkMonitor.isOnline` のとき `OfflineBannerView` を表示。記録自体は継続可能。 |
| 設定・リトライ導線 | `OfflineBannerView` — 「設定を開く」（`UIApplication.openSettingsURLString`）、「リトライ」（`networkMonitor.refreshStatus()`）。 |
| `SelectedTrack` への変換 | `TrackResolver.resolveSelectedTrack(from:)` — 手動入力は `SelectedTrack(spotifyTrackId: nil, userEnteredName: name)`（`Domain/Models/Flow/SelectedTrack.swift`）。 |

### 関連ファイル（主）

- `Sources/Presentation/Recording/TrackInput/TrackInputSectionView.swift`
- `Sources/Presentation/Recording/TrackInput/TrackInputState.swift`
- `Sources/Presentation/Recording/TrackInput/TrackResolver.swift`
- `Sources/Presentation/Recording/OfflineBannerView.swift`
- `Sources/Presentation/Recording/Sheet/RecordingSheetContentView.swift`

---

## [I-008] Intent選択画面（シート内）

### 実装内容

| タスク | 実装の所在・要点 |
|--------|------------------|
| Shout / Emo / Practice の3択 | `RecordingSheetIntentSection` — ボタンで `RecordingDraft.intent` にバインド。 |
| 選択状態を ViewModel で保持 | `RecordingDraft`（`RecordingSheetViewModel.draft`）が `intent` を保持。 |
| SelectedTrack と Intent を同一保存に | `RecordingSheetViewModel.save()` が `resolveSelectedTrack` の結果と `draft.intent` で `SingingSession` を生成。 |
| Intent 選択後すぐスコア・メモ・保存可能 | 同一 `RecordingSheetContentView` 上にスコア・メモ・保存 CTA を配置（追加遷移なし）。 |

### 関連ファイル（主）

- `Sources/Presentation/Recording/Sections/RecordingSheetIntentSection.swift`
- `Sources/Presentation/Recording/Sheet/RecordingSheetViewModel.swift`（`RecordingDraft`）

---

## [I-009] 歌唱記録入力画面

### 実装内容

| タスク | 実装の所在・要点 |
|--------|------------------|
| スコア（0〜100・Slider） | `RecordingSheetScoreSection` — `Slider(value:in: 0...100, step: 0.1)`。永続化時は ViewModel の `normalizedScoreForPersistence` で丸め。 |
| メモ（任意） | `RecordingSheetMemoSection` — `RecordingDraft.memo`。 |
| 保存・getOrCreate・saveNewRecordingSession | `RecordingSheetViewModel.save()` — `trackRepository.getOrCreate` → `sessionRepository.saveNewRecordingSession(session)`。 |
| 成功時に履歴タブ | `RecordingSheetContentView.attemptSave()` 成功時 `onSavedMoveToHistory()` → `SongsRootView` / `RootView` で履歴タブ選択。 |
| 失敗時エラー + 再試行 | `inlineErrorMessage` + `InlineErrorRetryView`（文言「保存に失敗しました。もう一度お試しください」）。 |

### 関連ファイル（主）

- `Sources/Presentation/Recording/Sections/RecordingSheetScoreSection.swift`
- `Sources/Presentation/Recording/Sections/RecordingSheetMemoSection.swift`
- `Sources/Presentation/Recording/InlineErrorRetryView.swift`
- `Sources/Presentation/Recording/Sheet/RecordingSheetContainerView.swift`

### 手動 QA

- [`docs/manual_qa_I008_I009_record_save.md`](../../../docs/manual_qa_I008_I009_record_save.md)

---

## [I-010] 二重送信防止（UI層）

### 実装内容

| タスク | 実装の所在・要点 |
|--------|------------------|
| 保存後すぐボタン非活性 | `bottomCTA` — `.disabled(viewModel.isSaving)`、ラベル「保存中...」。 |
| 保存中 ProgressView | `ZStack` 上層の半透明オーバーレイ + `ProgressView()`。 |
| インタラクションのブロック | オーバーレイで下層を覆う。`.interactiveDismissDisabled(viewModel.isSaving)`。閉じるボタン `.disabled(viewModel.isSaving)`。 |
| 完了後の復帰 | `save()` の `defer { isSaving = false }`。成功時は `dismiss` で離脱。 |

### ViewModel ガード

- `save()` 先頭 `guard !isSaving else { return false }`。

### 関連ファイル（主）

- `Sources/Presentation/Recording/Sheet/RecordingSheetContentView.swift`
- `Sources/Presentation/Recording/Sheet/RecordingSheetViewModel.swift`

---

## 影響範囲（本ログのスコープ）

| 層 | 内容 |
|----|------|
| **Presentation** | Recording Sheet 一式、手動入力・Intent・スコア・メモ・保存 UI、オフライン表示、I-010 の `isSaving` |

---

## 関連ログ

- データ層冪等（I-011）: [`../i-011-data-idempotency/20260321_i011_implementation.md`](../i-011-data-idempotency/20260321_i011_implementation.md)
