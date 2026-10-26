---
paths:
  - "Karaoke_support/Karaoke_support/Sources/Domain/Models/**"
  - "Karaoke_support/Karaoke_support/Sources/Domain/Repositories/**"
  - "Karaoke_support/Karaoke_support/Sources/Data/**"
  - "Karaoke_support/Karaoke_support/Sources/App/AppDependencies.swift"
---

# SwiftData のモデルと Repository

全体像は `docs/architecture.md` の「データベース（SwiftData）」の節を見る。

## `@Model` の項目を足す・変えるとき

- 新しい項目は**必ず空を許す形（Optional）**で足す。SwiftData の自動の移行では、前からある記録の新しい欄は空のままになり、空を許さない enum だと読んだときに落ちる（ADR 0034）。呼び出す側に初期値が要るなら、空を許さない計算プロパティを別に用意する。
- `VersionedSchema` は使っていない。「空を許す項目を足す」以外の変更（名前の変更、型の変更、必須の項目の追加）は、先に ADR を足す。
- 出す前に、前のビルドで作ったデータを新しいビルドで開き、記録が消えずに読めることを確かめる。

## 書き込み

- 書き込みは必ず Repository を通す。View から `ModelContext` を触らない。
- `ModelContext` はスレッドセーフではないので、Repository は `@MainActor` で動かす。
- **冪等な保存**：`saveNewRecordingSession` は先に `exists(uuid:)` を見て、すでにある id なら何もしない。ViewModel でも `isSaving` で連打を止める。両方が要る（ADR 0006）。
- すでにある記録の id を `saveNewRecordingSession` に渡さない。編集は `updateRecordingSession` を通し、書き換えるのは気分・日時・点数・メモ・ハート（`recordedWantAgain`）だけ（曲と `recordedSource` は変えない）。
- `singCount` は新規の保存で 1 増やし、削除で 1 減らす。曲は `userEnteredName` が完全に同じなら使い回し、消さない。

## 読み込み

- `#Predicate` の中で enum を使わない。直近の分を読んでからメモリで絞る（ADR 0007、`SwiftDataSessionRepository.fetchByIntent`）。
- 集計（ランキング、曲ごとの集計、入口の数）は読むたびに計算し、保存しない（ADR 0029）。
- `UserDefaults` は UI の目印だけに使う。記録や外部の曲のメタデータは入れない（今は使っていない）。

## このフォルダを変えたら見直す文書

- `docs/architecture.md` の「データベース（SwiftData）」の節（モデル・書き込み・読み方）
- CLAUDE.md の「主なモデル」の表
- 判断をしたら `docs/adr/`
