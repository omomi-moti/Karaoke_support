# feature/i-001-project-init 実装ログ

**日付**: 2025-03-14  
**対象**: [I-001] プロジェクト初期化

---

## ブランチの概要

iOS アプリ「ヒトカラモバイル」のプロジェクトをゼロから初期化し、iOS 17+・Swift 5.9 前提で開発可能な状態にすることを目的とした実装である。Xcode で新規 iOS プロジェクトを作成し、SwiftUI を採用。デフォルトの ContentView は使わず、ルートを `RootView` に整理。さらに `.cursorrules` および憲法で定めるレイヤー構成（Presentation / Domain / Data）に沿ったフォルダ雛形をソースルート配下に作成し、デプロイメントターゲットを iOS 17.0 に統一している。あわせて、仕様・設計・Issue 管理用のドキュメント（docs/・specs/）や Cursor 用コマンド（.cursor/）、spec 運用スクリプト（.specify/）など、リポジトリ全体の基盤もこのブランチで追加されている。

---

## 主な実装・変更点

### 追加された機能・構成

- **Xcode プロジェクト**
  - アプリターゲット `Karaoke_support`、ユニットテスト `Karaoke_supportTests`、UI テスト `Karaoke_supportUITests` を新規作成。
  - ビルド設定: `IPHONEOS_DEPLOYMENT_TARGET = 17.0`、`SWIFT_VERSION = 5.9`（App / Tests / UITests で統一）。
  - `PBXFileSystemSynchronizedRootGroup` により、アプリソースフォルダをファイルシステムと同期。

- **アプリエントリ・ルート UI**
  - `Sources/App/KaraokeSupportApp.swift`: `@main` で `WindowGroup { RootView() }` を表示。
  - `Sources/Presentation/Root/RootView.swift`: ルート画面（現状は「Karaoke support」テキスト＋`#Preview`）。

- **レイヤー雛形（Sources 配下）**
  - **Presentation**: `Root/`（実装済み）、`History/`、`Insight/`、`Recording/`、`Search/`（各 `.gitkeep` のみ）。
  - **Domain**: `Models/`、`Repositories/`（各 `.gitkeep` のみ）。
  - **Data**: `SwiftData/`、`Spotify/`、`Cache/`（各 `.gitkeep` のみ）。

- **リソース・テスト**
  - `Assets.xcassets`（AppIcon、AccentColor、Contents.json）。
  - `Karaoke_supportTests.swift` / `Karaoke_supportUITests.swift` / `Karaoke_supportUITestsLaunchTests.swift`: デフォルトのテストスタブ。

- **ドキュメント・仕様・ツール**
  - `docs/`: 基本設計・詳細設計・Issue 一覧・raw_spec・クロスチェック報告など。
  - `specs/001-hitora-karaoke-ios/spec.md` およびチェックリスト。
  - `.cursorrules`、`.cursor/commands/`（speckit 系コマンド）、`.specify/`（憲法・スクリプト・テンプレート）、`.gitignore` の追加。

### 修正された箇所

- 特になし（main からの新規追加が主）。

### 削除された不要なコード

- デフォルトの `ContentView.swift` は作成せず、最初から `RootView` をルートにしている（不要ファイルの整理に相当）。

---

## 影響範囲

| 対象 | 内容 |
|------|------|
| **アプリ本体** | 起動時に `KaraokeSupportApp` → `RootView` が表示される。今後の画面は `Sources/Presentation/` 各サブフォルダに追加する想定。 |
| **ビルド設定** | 全ターゲットで iOS 17.0・Swift 5.9 に統一。macOS/XROS 等のデプロイメントターゲットは別設定のまま。 |
| **テスト** | ユニット・UI テストターゲットは存在するが、実テストは未実装（スタブのみ）。 |
| **リポジトリ全体** | docs・specs・. cursor・.specify の追加により、今後の Issue/仕様駆動の開発基盤が整備された。 |

---

## 特記事項

- **Swift バージョン**: プロジェクト設定は `SWIFT_VERSION = 5.9`。仕様で Swift 5.9 前提としているため、必要に応じて 6.0 への上げ・並行処理チェックの対応を検討できる。
- **アプリ名の表記**: エントリは `KaraokeSupportApp`（CamelCase）、プロジェクト名は `Karaoke_support`。ファイル配置は `Karaoke_support/` 配下で一貫している。
- **未実装**: Domain/Data の実装は I-002 以降（SwiftData モデル・Repository 等）。Presentation の History / Insight / Recording / Search はフォルダのみで、画面は未実装。
- **ビルド確認**: `xcode-select` が Xcode 本体を指していない環境では `xcodebuild` が失敗するため、実機・シミュレータでの動作確認は Xcode からビルド（⌘B）で行う必要がある。
