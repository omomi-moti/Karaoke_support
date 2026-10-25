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
| [0008](0008-single-recording-sheet-on-root.md) | 歌唱記録は 1 枚のシートにまとめ、`RootView` に 1 つだけ置く | 置き換え済み（→ 0025） |
| [0009](0009-tiered-track-suggestions.md) | 曲名の候補は一致した場所で段を分けて並べる | 承認 |
| [0010](0010-issues-and-adr-as-source-of-truth.md) | タスクは GitHub Issues、判断は ADR を正とし、旧 Issue 一覧は archive に残す | 承認 |
| [0011](0011-identify-tracks-by-name-and-artist.md) | 手入力の曲は曲名＋歌手名で区別し、新しい曲では歌手名を必須にする | 提案 |
| [0012](0012-score-three-decimals-optional.md) | 点数は小数第3位までの任意入力にする | 承認 |
| [0013](0013-score-input-with-system-number-pad.md) | 点数は標準テンキーで右詰めに入力し、入力欄は見えなくする | 承認 |
| [0014](0014-score-display-without-rounding.md) | 点数は丸めず小数第3位まで表示し、平均は切り捨てる | 承認 |
| [0015](0015-performed-at-from-save-time.md) | 新規記録の歌唱日時は保存した時刻にし、日時欄は編集のときだけ出す | 承認 |
| [0016](0016-unify-intent-colors-and-icons.md) | Intent の色とアイコンを、記録シート・履歴・曲詳細でそろえる | 承認 |
| [0017](0017-chip-glow-without-scroll-clipping.md) | 選んだチップの光は、ScrollView の切り取りを止めて見せる | 承認 |
| [0018](0018-history-row-navigation-with-button.md) | 履歴の行は NavigationLink ではなく Button で曲詳細を開く | 承認 |
| [0019](0019-show-edit-mode-in-recording-sheet.md) | 記録の編集中は、帯・「更新する」・読むだけの曲名で新規と見分けられるようにする | 承認 |
| [0020](0020-hide-add-button-on-edit-screen.md) | 編集画面では＋ボタンを、画面から PreferenceKey で伝えて隠す | 置き換え済み（→ 0022） |
| [0021](0021-single-add-button-measured-from-tab-safe-area.md) | ＋ボタンは `RootView` に 1 つだけ置き、タブバーの高さはタブの中身の安全領域から測る | 承認 |
| [0022](0022-open-edit-in-root-sheet.md) | 記録の編集も `RootView` のシートで開き、＋ボタンを隠す仕組みをなくす | 承認 |
| [0023](0023-add-button-glass-fixed-color-and-size.md) | ＋ボタンはガラスのまま、ライト・ダーク共通の濃いめのピンクにし、大きさは固定にする | 承認 |
| [0024](0024-recommend-right-after-save.md) | 次の 1 曲の提案は、記録を保存した直後にシートで出す | 承認 |
| [0025](0025-switch-root-sheet-after-save.md) | 記録シートと保存直後のシートは、`RootView` の 1 つのシートで切り替え、閉じ終わってから次を出す | 承認 |
| [0026](0026-next-track-recommendation-weights.md) | 次の 1 曲の提案は端末の中の純粋関数で決め、点数を久しぶり度の 4 倍に重み付けする | 承認 |
| [0027](0027-sendable-repository-protocols-for-environment-keys.md) | Repository の EnvironmentKey は、プロトコルを Sendable にし、初期値をメインアクターの外で作れるようにする | 承認 |
| [0028](0028-save-returns-saved-recording.md) | 記録シートの `save()` は、成否と保存した記録の要約を 1 つの値（`SavedRecording?`）で返す | 承認 |
| [0029](0029-recompute-track-stats-without-cache.md) | 提案に使う曲ごとの集計はキャッシュせず、保存のたびに全部の記録から作り直す | 承認 |
| [0030](0030-delay-after-save-sheet.md) | 保存直後のシートは、保存してから 1 秒たってから出す | 置き換え済み（→ 0032） |
| [0031](0031-environment-values-by-default-identity.md) | 環境に置くものは、初期値に同一性があるかで書き方を分ける | 承認 |
| [0032](0032-move-to-history-after-dismiss.md) | 保存したら、記録シートが閉じ終わってから履歴タブへ移り、その 1 秒後に保存直後のシートを出す | 承認 |
| [0033](0033-show-error-when-store-cannot-open.md) | 保存先の DB を開けなかったときは、メモリ上の DB で起動せず、エラー画面で止める | 承認 |

## 書き方

ファイル名は `番号-英語の短い名前.md`（例：`0012-score-three-decimals-optional.md`）。番号は 4 桁の連番。

```markdown
# 0021. 判断を 1 行で

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
