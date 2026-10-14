# 技術判断の記録（ADR）

設計・実装で何を比べ、なぜそれを選んだかを 1 件 1 ファイルで残す（[0001](0001-record-decisions-as-adr.md)）。保存フロー・冪等性の全体像は [architecture.md](../architecture.md) の「歌唱記録の保存フロー」を参照。

## 一覧

| 番号 | 判断 | ステータス |
|---|---|---|
| [0001](0001-record-decisions-as-adr.md) | 技術判断を ADR として 1 件 1 ファイルで残す | 承認 |
| [0002](0002-no-persisting-spotify-metadata.md) | Spotify のメタデータは永続化せず、曲は ID とユーザー入力だけ持つ | 承認 |
| [0003](0003-inject-repositories-via-environment.md) | Repository は Protocol で定義し、`@Environment` で注入する | 承認 |
| [0004](0004-discard-stale-results-by-generation.md) | 非同期の古い結果は世代番号で捨てる | 承認 |
| [0005](0005-history-value-snapshots.md) | 履歴は値型のスナップショットで持つ | 承認 |
| [0006](0006-idempotent-save-in-ui-and-data.md) | 保存の冪等性を UI 層とデータ層の両方で守る | 承認 |
| [0007](0007-filter-intent-in-memory.md) | enum を含む `#Predicate` を使わず、メモリで絞り込む | 承認（見直し候補） |
| [0008](0008-single-recording-sheet-on-root.md) | 歌唱記録は 1 枚のシートにまとめ、`RootView` に 1 つだけ置く | 承認 |
| [0009](0009-tiered-track-suggestions.md) | 曲名の候補は一致した場所で段を分けて並べる | 承認 |
| [0010](0010-issues-and-adr-as-source-of-truth.md) | タスクは GitHub Issues、判断は ADR を正とし、旧 Issue 一覧は archive に残す | 承認 |
| [0011](0011-identify-tracks-by-name-and-artist.md) | 手入力の曲は曲名＋歌手名で区別し、新しい曲では歌手名を必須にする | 提案 |

## 書き方

ファイル名は `番号-英語の短い名前.md`（例：`0012-score-three-decimals.md`）。番号は 4 桁の連番。

```markdown
# 0012. 判断を 1 行で

- 2026-10-14 ／ 承認
- 背景：何に困って、何を決めたか（1〜2 行）

## 比較した案
- A. …
- B. …

## トレードオフ
- A は … だが …
- B は … だが …

## 選んだ理由
- B。…

## 見直す条件
- どうなったら見直すか

関連：#Issue 番号、PR、関連する文書（あれば）
```

## 運用

- ステータスは「提案」「承認」「置き換え済み（→ 番号）」のどれか
- 承認した ADR の本文は書き換えない。判断を変えるときは新しい番号で ADR を足し、古い方のステータスを「置き換え済み（→ 番号）」にする（この一覧のステータスも合わせて直す）
- 新しい ADR を足したら、この一覧に 1 行足す
- 別のブランチで同じ番号を使ってしまったら、後からマージする方が番号を振り直す
- 憲法（[constitution.md](../../.specify/memory/constitution.md)）が上位。ADR は憲法の範囲内での判断を書く
