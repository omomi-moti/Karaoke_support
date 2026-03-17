## I-005 InsightRepository 実装ログ (2026-03-14)

### 目的
- `InsightRepository` を追加し、ローカルDB（SwiftData）からインサイト用ランキングを生成する。
- 仕様（`docs/raw_spec.md`）の「タイムマシン」「マイアンセム」に対応する。

### 仕様との対応
- **タイムマシン**: 「過去1ヶ月で歌った曲のランキング」
  - 実装: `SingingSession.performedAt >= now - 1 month` で絞り込み、`Track` 単位に回数集計して降順ソート。
- **マイアンセム**: intent（emo/shout/practice）ごとの「回数ランキング」「点数ランキング」
  - 実装: intent ごとに `SingingSession` を取得し、`Track` 単位に
    - 回数（count）
    - 点数（bestScore = max）
    を集計してそれぞれ降順ソート。

### 実装方針（SwiftData集計の制約）
- SwiftData は SQL の `GROUP BY` のような集計クエリを直接書きにくいため、
  - FetchDescriptor で対象 `SingingSession` を取得
  - メモリ上で `Track.id` で集約
  の手法を採用。
- 現状の v1 スコープではデータ量が極端に大きくない前提のため許容するが、将来的に件数が増える場合は最適化（期間絞り込みの徹底、ページング、集計キャッシュ等）を検討。

### 追加/変更したもの
- `Sources/Domain/Repositories/InsightRepositoryProtocol.swift`
- `Sources/Domain/Models/InsightTrackCountRanking.swift`
- `Sources/Domain/Models/InsightTrackScoreRanking.swift`
- `Sources/Domain/Models/MyAnthemRanking.swift`
- `Sources/Data/SwiftData/SwiftDataInsightRepository.swift`
- `Sources/Domain/Models/Intent.swift`（`CaseIterable` 追加）

### 仕様書との齟齬チェック結果
- `docs/raw_spec.md` の「タイムマシン（過去1ヶ月）」要件に対して、期間フィルタを実装済み。
- 「マイアンセム（intent別の回数/点数ランキング）」要件に対して、intent別の2ランキングを実装済み。
- 「曲メタデータを永続化しない」方針に反しない（Track自体を返すが、メタデータは Track に保持していない設計のまま）。

