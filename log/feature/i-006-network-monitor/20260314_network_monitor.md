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
  - **NetworkMonitor**（`@Observable` な final class）
    - `NWPathMonitor` で接続状態を監視。`path.status == .satisfied` を online とする。
    - `isOnline: Bool`（`private(set)`）で状態を公開。SwiftUI から参照すると再描画される。
    - `init()` 内で `monitor.start(queue:)` を呼び、アプリ起動時に監視を開始。
    - `pathUpdateHandler` 内で `DispatchQueue.main.async` により `isOnline` を更新し、UI 更新をメインスレッドで行う。
    - `deinit` で `monitor.cancel()` を呼び、監視を停止する。
  - **EnvironmentKey**
    - `NetworkMonitorEnvironmentKey`（private）で `defaultValue` に `NetworkMonitor()` を指定。
    - `EnvironmentValues` に `networkMonitor` を追加。`@Environment(\.networkMonitor)` で参照可能。

### 変更されたファイル

- **Sources/App/KaraokeSupportApp.swift**
  - **変更内容**: `@State private var networkMonitor = NetworkMonitor()` を追加し、`RootView()` に `.environment(\.networkMonitor, networkMonitor)` を付与した。
  - **変更理由**: アプリ全体で 1 インスタンスの NetworkMonitor を共有するため、App で生成して環境に注入する。`@State` にした理由は、App の struct が SwiftUI により再生成されても同一インスタンスを保持し、監視の二重起動や参照の不整合を防ぐためである。

---

## 影響範囲

| 対象 | 内容 |
|------|------|
| **Data 層** | `Sources/Data/Network/NetworkMonitor.swift` が追加された。Network フレームワークに依存する。 |
| **App エントリ** | `KaraokeSupportApp` で NetworkMonitor を生成・保持し、ルート View に注入している。 |
| **今後の利用** | I-012 手動曲名入力画面で `@Environment(\.networkMonitor)` を取得し、`isOnline` が false のときにオフライン用メッセージを表示する想定。 |

---

## 特記事項

- **接続状態の公開**: 仕様書の「@Published または AsyncStream」に対し、iOS 17+ の `@Observable` で `isOnline` を公開している。SwiftUI からそのまま購読可能である。
- **スレッド**: `pathUpdateHandler` は NWPathMonitor のキューで呼ばれるため、`isOnline` の更新は `DispatchQueue.main.async` でメインスレッドに寄せている。
- **EnvironmentKey の default**: `defaultValue` に `NetworkMonitor()` を指定しているため、注入されていないコンテキスト（プレビュー等）でも参照は可能。本番では App で 1 インスタンスを注入する。
