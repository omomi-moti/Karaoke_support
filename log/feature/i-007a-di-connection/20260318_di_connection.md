# feature/i-007a-di-connection 実装ログ

**日付**: 2026-03-18  
**対象**: [I-007A] 依存性注入（DI）接続

---

## 概要

SwiftData の `ModelContainer` と、各 Repository（Session/Track/Insight）の具体実装を App 起点で生成し、SwiftUI の `@Environment` 経由で参照できるよう DI 配線を整備した。

EnvironmentKey / EnvironmentValues 拡張は App 層（`Sources/App/`）に配置し、Data 層は SwiftUI に依存しない構成を維持した。

---

## 主な実装・変更点

### 追加されたファイル（App層）

- **Sources/App/SessionRepositoryEnvironment.swift**
- **Sources/App/TrackRepositoryEnvironment.swift**
- **Sources/App/InsightRepositoryEnvironment.swift**
  - `EnvironmentKey` と `EnvironmentValues` 拡張を追加し、`\.sessionRepository` / `\.trackRepository` / `\.insightRepository` を提供。
  - `defaultValue` はプレビュー向けのスタブ実装を返す。

### 追加されたファイル（プレビュー向けスタブ）

- **Sources/App/PreviewSessionRepository.swift**
  - 最小のサンプルセッションを返せるようにし、UI確認の価値を上げた。
- **Sources/App/PreviewTrackRepository.swift**
  - `getOrCreate` は「両方nil/空のみ throw」を守り、プレビューでも契約違反にならないようにした。
- **Sources/App/PreviewInsightRepository.swift**
  - タイムマシン/マイアンセム用に最小のサンプルランキングを返す。

### 変更されたファイル

- **Sources/App/KaraokeSupportApp.swift**
  - `ModelContainer` を App init で明示生成し、`mainContext` を使って `SwiftDataSessionRepository` / `SwiftDataTrackRepository` / `SwiftDataInsightRepository` を生成。
  - 生成した Repository を `RootView()` に `.environment(...)` で注入。
  - 永続ストア生成失敗時は in-memory ストアへフォールバック（環境差・テスト容易性のため）。
- **docs/v1_issues.md**
  - I-007A のうち、App起点生成とEnvironmentKey定義・注入の項目を完了（`[x]`）に更新。

---

## 未対応（意図して残している項目）

- **View → ViewModel への接続（初期化引数でRepository注入）**
  - ViewModel が未実装の段階では接続先が存在しないため、I-013（歌唱記録フロー）等で ViewModel を追加したタイミングで対応する。

---

## 仕様書との照合・検証（2026-03-18）

| 仕様（v1_issues.md I-007A） | 実装 | 判定 |
|---|---|---|
| AppエントリでModelContainer参照 | `KaraokeSupportApp` で `ModelContainer` を生成し `.modelContainer(modelContainer)` | ✅ |
| Session/Track/InsightRepository の具体実装を生成 | `SwiftData*Repository(modelContext: mainContext)` を生成 | ✅ |
| EnvironmentKey を App 層に定義してルートに注入 | `Sources/App/*RepositoryEnvironment.swift` + `.environment(...)` | ✅ |
| 各ViewModelがEnvironmentから取得してinit注入 | ViewModel未実装のためI-013で実施 | ⏳ |

**致命的バグの有無**: なし。Repository生成・注入は App の MainActor で実行され、SwiftDataの `ModelContext` を跨ぐ並行性リスクを避ける構成になっている。

