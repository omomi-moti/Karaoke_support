# feature/i-006-network-monitor 実装ログ

**日付**: 2026-03-14  
**対象**: [I-006] ネットワーク監視ユーティリティ

---

## ブランチの概要

NWPathMonitor を用いてオンライン/オフラインを検知し、接続状態を `@Observable` で公開する。EnvironmentKey を定義し、App 起点で `@Environment(\.networkMonitor)` から参照できるようにした。I-012 の手動曲名入力画面などでオフライン時のメッセージ表示に利用する想定である。

---

## 主な実装・変更点

### 追加されたファイル

- **Sources/Data/Network/NetworkMonitor.swift**
  - **NetworkMonitor**（`@MainActor` + `@Observable` な final class）
    - `NWPathMonitor` で接続状態を監視。`path.status == .satisfied` を online とする。
    - `isOnline: Bool`（`private(set)`）で状態を公開。SwiftUI から参照すると再描画される。
    - `init()` 内で `monitor.start(queue:)` を呼び、アプリ起動時に監視を開始。`queue` のデフォルトは `.main`。
    - `pathUpdateHandler` は queue: .main によりメインスレッドで実行され、直接 `isOnline` を更新する（`DispatchQueue.main.async` 不要）。Swift 6 厳格並行性に対応。
    - `init(queue:startsMonitoring:)` で `startsMonitoring: false` を指定した場合は `NWPathMonitor` を生成・start せず、プレビューや EnvironmentKey の default 用に利用する。
    - `deinit` で `monitor?.cancel()` を呼び、監視を停止する。
    - Data 層は SwiftUI に依存しない。`import Observation` のみ（`@Observable` 用）。
- **Sources/App/NetworkMonitorEnvironment.swift**
  - **EnvironmentKey**（App 層の DI 配線）
    - `NetworkMonitorEnvironmentKey`（private）で `defaultValue` に `NetworkMonitor(startsMonitoring: false)` を指定。注入されないコンテキスト（プレビュー等）では監視を起動せず、`isOnline` は常に false。
    - `EnvironmentValues` に `networkMonitor` を追加。`@Environment(\.networkMonitor)` で参照可能。
    - constitution / .cursorrules に従い、Data 層から SwiftUI 依存を分離し、Environment 配線は App 層に配置。

### 変更されたファイル

- **Sources/App/KaraokeSupportApp.swift**
  - **変更内容**: `@State private var networkMonitor = NetworkMonitor()` を追加し、`RootView()` に `.environment(\.networkMonitor, networkMonitor)` を付与した。
  - **変更理由**: アプリ全体で 1 インスタンスの NetworkMonitor を共有するため、App で生成して環境に注入する。`@State` にした理由は、App の struct が SwiftUI により再生成されても同一インスタンスを保持し、監視の二重起動や参照の不整合を防ぐためである。

---

## 影響範囲

| 対象 | 内容 |
|------|------|
| **Data 層** | `Sources/Data/Network/NetworkMonitor.swift`。Network / Observation のみに依存。SwiftUI 非依存。 |
| **App 層** | `Sources/App/NetworkMonitorEnvironment.swift` で EnvironmentKey を定義。`KaraokeSupportApp` で NetworkMonitor を生成・保持し、ルート View に注入。 |
| **今後の利用** | I-012 手動曲名入力画面で `@Environment(\.networkMonitor)` を取得し、`isOnline` が false のときにオフライン用メッセージを表示する想定。 |

---

## 特記事項

- **接続状態の公開**: 仕様書の「@Published または AsyncStream」に対し、iOS 17+ の `@Observable` で `isOnline` を公開している。SwiftUI からそのまま購読可能である。
- **スレッド**: `@MainActor` と `queue: .main` により、`pathUpdateHandler` はメインスレッドで実行されるため、直接 `isOnline` を更新する。Swift 6 厳格並行性に対応。
- **EnvironmentKey の default**: `defaultValue` は `NetworkMonitor(startsMonitoring: false)` とし、プレビュー等で参照されても NWPathMonitor を起動しない。本番では App で `NetworkMonitor()`（監視あり）を 1 インスタンスだけ注入し、子 View はそのインスタンスを参照する。
- **レイヤー分離**: Data 層（NetworkMonitor）は SwiftUI に依存せず `import Observation` のみ。EnvironmentKey / EnvironmentValues 拡張は App 層（NetworkMonitorEnvironment.swift）に配置。constitution / .cursorrules の責務分離に準拠。

---

## 仕様書との照合・検証（2026-03-14）

| 仕様（v1_issues.md I-006） | 実装 | 判定 |
|---------------------------|------|------|
| NWPathMonitor を用いた NetworkMonitor を作成 | `NWPathMonitor` + `@Observable` の `NetworkMonitor` class | ✅ |
| 接続状態を @Published または AsyncStream で公開 | `@Observable` で `isOnline` を公開（SwiftUI で購読可能） | ✅ 同等 |
| アプリ起動時に監視を開始し状態変化を検知 | App で `NetworkMonitor()` を生成し `start(queue:)` により監視開始 | ✅ |
| EnvironmentKey を定義し App 起点で注入 | `\.networkMonitor` を定義し、`KaraokeSupportApp` で RootView に注入 | ✅ |

**致命的バグの有無**: なし。`@MainActor` + `queue: .main` によるメインスレッドでの `isOnline` 更新、`deinit` での `cancel`、本番で監視 1 本・default で 0 本であることを確認済み。
