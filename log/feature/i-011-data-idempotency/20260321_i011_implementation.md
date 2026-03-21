# feature/i-011-data-idempotency 実装ログ

**日付**: 2026-03-21  
**対象**: [I-011] 二重送信防止（データ層）

**参照 Issue**: [`docs/v1_issues.md`](../../../docs/v1_issues.md)（I-011）

---

## 概要

歌唱記録の永続化は **`SessionRepository.saveNewRecordingSession`** のみを用いる。保存前に **`exists(uuid:)`** で `SingingSession.id` の有無を確認し、既存なら **insert も `Track.singCount` 加算も行わず**成功扱い（冪等）。クライアント側は **`RecordingSheetViewModel.pendingSessionIdForSave`** にクライアント生成 UUID を保持し、保存失敗後の再試行で同一キーを再利用する。

Recording Sheet の UI・手動入力・I-010 は別ログ [`../i-008-i-012-i-009-i-010/20260321_recording_sheet_ui.md`](../i-008-i-012-i-009-i-010/20260321_recording_sheet_ui.md) を参照。

---

## [I-011] 二重送信防止（データ層）

### 実装内容

| タスク | 実装の所在・要点 |
|--------|------------------|
| 保存前に `SessionRepository.exists(uuid)` | `SwiftDataSessionRepository.saveNewRecordingSession` 先頭で `if try await exists(uuid: session.id) { return }`。 |
| 既存ならスキップ | 上記により **insert・`singCount` 更新をスキップ**し二重登録を防止。 |
| クライアント UUID を Idempotency Key | `RecordingSheetViewModel` — 初回保存で `UUID()` を生成し `pendingSessionIdForSave` に保持。成功で `nil` にクリア。失敗時は同じ ID で `save()` を再実行可能。 |
| 冪等性の検証 | `Karaoke_supportTests/I011SessionIdempotencyTests.swift` — 同一 UUID で `saveNewRecordingSession` を2回呼び、セッション行数が 1、`track.singCount` が二重に増えないことを検証。 |

### Repository

- **`Sources/Data/SwiftData/SwiftDataSessionRepository.swift`** — `saveNewRecordingSession` / `exists`
- **`Sources/App/PreviewSessionRepository.swift`** — プレビュー用に同一冪等セマンティクス（保存済み ID を `Set` で保持）

### Domain

- **`Sources/Domain/Repositories/SessionRepositoryProtocol.swift`** — 歌唱記録の永続は `saveNewRecordingSession` のみ（生の `save(session:)` は廃止済みの想定で、記録の単一入口）

### ViewModel（Idempotency Key 保持）

- **`Sources/Presentation/Recording/RecordingSheetViewModel.swift`** — `pendingSessionIdForSave`

---

## 単体テスト

| ファイル | 内容 |
|----------|------|
| `Karaoke_supportTests/I011SessionIdempotencyTests.swift` | 同一 `SingingSession.id` で2回 `saveNewRecordingSession` しても行数・`singCount` が増えないこと |

---

## 影響範囲（本ログのスコープ）

| 層 | 内容 |
|----|------|
| **Presentation** | `RecordingSheetViewModel` の `pendingSessionIdForSave` のみ（I-011 のクライアント側キー） |
| **Data** | `SwiftDataSessionRepository.saveNewRecordingSession` + `exists` |
| **Domain** | `SessionRepositoryProtocol` |

---

## 関連ログ

- Recording Sheet UI（I-012 / I-008 / I-009 / I-010）: [`../i-008-i-012-i-009-i-010/20260321_recording_sheet_ui.md`](../i-008-i-012-i-009-i-010/20260321_recording_sheet_ui.md)

---

## 将来の改善メモ（ログ・エラー）

**いま**: `RecordingSheetViewModel.save()` は失敗時に **`catch` で一律メッセージ**（ユーザー向け文言の共通化）。

**本当に調査が必要になったら**（障害・再現が増えたら）で十分な段階:

- **エラー種別**を分ける（例: SwiftData の `save` 失敗 / ユニーク制約 / その他）し、**開発ビルドや匿名ログ**で原因を切り分けやすくする。
- フルな構造化ログまでは必須にしない。**種別が分かれば十分**なことが多い。

**手動 QA**: 境界挙動は [`docs/manual_qa_I008_I009_record_save.md`](../../../docs/manual_qa_I008_I009_record_save.md) の「失敗 → スコア変更 → 再試行」を参照。
