# CLAUDE.md

このリポジトリで作業する Claude Code（claude.ai/code）への案内。一部のフォルダだけに効く決まりは `.claude/rules/` にあり、そのフォルダのファイルを触ったときに読み込まれる。

---

## Claude との作業の約束

本人は、書くことは Claude に任せつつ、すべての変更を理解し、コードの質を保ちたい。

- **日本語で答える。** 文書（CLAUDE.md・ルール・ADR・docs・スキル）も日本語で書く。コードの識別子・コマンド・ファイル名は英語のまま（ADR 0035）。
- **実装の前に、どのファイルの何を、なぜ変えるかを必ず書き出してから実装する。** 黙って書き換え始めない。
- 何段階もある作業は、変えるファイルと順番の案を出し、了承をもらってから始める。ブランチも、作る前に名前の案を出す。
- 差分は最小にする。説明のためのコメントはコードに入れず、チャットで説明する。契約を書く doc コメントはよい。
- **文書の更新を確かめる。** 手順ごとに、コミットの分け方を出す前に、文書（CLAUDE.md・`.claude/rules/`・docs・README・ADR）の更新が要るか確かめ、結果を一言書く（「要らない」または「これを直す」）。直すなら同じ手順で直す。フォルダごとに見る文書は各ルールの最後に書いてある。それ以外は次のとおり：
  - 設計の判断をした・変えた → `docs/adr/` に 1 件足す
  - 作業の進め方や AI の使い方を変えた → `docs/development_process.md` と、この CLAUDE.md
  - 機能を足した・変えた → `README.md`（説明・スクリーンショット・テストの表）と `docs/product_overview.md`
- **コミットは本人がする。** 手順ごとに、ファイルの分け方（`git add …`）とコミットメッセージを出す。「コミットして」と頼まれたときだけ Claude がコミットする。`Karaoke_support.xcodeproj/project.pbxproj` のビルド番号は、頼まれない限り入れない。
- PR は、タイトルと「背景」「変更内容」だけの本文にし、最後に `Closes #N` を書く。
- **ADR**：背景・比べた案・トレードオフは Claude が書く。「選んだ理由」は本人が自分の言葉で書くので、`<!-- 本人が書く -->` を置いて空けておく。
- PR の前に `karaoke-review` のスキルでレビューする。確かめていない推測を不具合として出さない。確かめるか、確かめていないと書く。

---

## ビルドとテスト

外部のパッケージマネージャーはない Xcode のプロジェクト。ビルドとテストは Xcode か `xcodebuild` で行う。

```bash
# ビルド（シミュレーター）
xcodebuild build \
  -project Karaoke_support/Karaoke_support.xcodeproj \
  -scheme Karaoke_support \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# ユニットテストを全部
xcodebuild test \
  -project Karaoke_support/Karaoke_support.xcodeproj \
  -scheme Karaoke_support \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# 1 つのテストクラスだけ
xcodebuild test \
  -project Karaoke_support/Karaoke_support.xcodeproj \
  -scheme Karaoke_support \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:Karaoke_supportTests/HistoryViewModelPaginationTests
```

リンターはない。Swift コンパイラの警告をリントの代わりにする。

---

## アーキテクチャ

**構成**：SwiftUI + SwiftData（iOS 26 以上）、`@Observable`、Swift Concurrency。外部の依存はない。

**パターン**：MVVM + Repository。DI は `@Environment` で手で行う。詳しくは `docs/architecture.md`（レイヤー、データの流れ、データベース、ユーザーフロー）。

```
Sources/
├── App/          # @main、AppDependencies、EnvironmentKey、プレビュー用のモック
├── Presentation/ # View + ViewModel（1 画面 1 ViewModel）。機能ごとのサブフォルダ
├── Domain/       # プロトコル、@Model、enum、ヘルパー。SwiftUI を読み込まない
└── Data/         # Repository の具体的な実装（SwiftData、NetworkMonitor）。SwiftUI を読み込まない
```

**依存の向き**：`Presentation → Domain のプロトコル`。`Data` は Domain のプロトコルを実装し、起動時に注入する。`Presentation` は `Data` の型を参照しない。

### DI の配線

`ModelContainer` と Repository は `AppDependencies.make(configuration:)` の 1 か所で作る。`KaraokeSupportApp` がその結果を持ち、`Sources/App/Environment/` の `EnvironmentKey` で Repository を注入する。Container の View は `@Environment(\.sessionRepository)` などで読み、ViewModel の `init` に渡す。プレビュー用のモックは `Sources/App/PreviewSupport/`。

保存先の DB を開けなかったときは `DataLoadErrorView` を出し、メモリ上の DB には切り替えない（ADR 0033）。デバッグのビルドでは `KARAOKE_SIMULATE_DATA_LOAD_FAILURE=1` でこの画面を出せる。

環境に置く値の書き方は、初期値に同一性があるかで分ける（ADR 0031）。

- **値とクロージャ**（`historyReloadTick`、`navigateTo…`）：`@Entry`
- **状態を持つ参照型**（Repository）：`EnvironmentKey` + `static let defaultValue`。Repository のプロトコルは `@MainActor` かつ `Sendable`。プレビュー用の Repository は `nonisolated init()` を持つ（ADR 0027）
- **アプリに 1 つの `@Observable` のオブジェクト**（`NetworkMonitor`）：`.environment(networkMonitor)` / `@Environment(NetworkMonitor.self)`。初期値はない

### 主なモデル

| 型 | ファイル | メモ |
|------|------|-------|
| `Track` | `Domain/Models/SwiftData/Track.swift` | `userEnteredName`（今は必ず入る）か `spotifyTrackId`（使っていない。常に nil） |
| `SingingSession` | `Domain/Models/SwiftData/SingingSession.swift` | UUID が冪等キー。Track と N:1 |
| `Intent` | `Domain/Models/Enums/Intent.swift` | `.shout` / `.emo` / `.practice`。RawValue は `String` |
| `RecordSource` | `Domain/Models/Enums/RecordSource.swift` | `.manual` / `.suggestion` / `.selectionScreen`。空を許す `recordedSource` に保存し、`source` で読む（ADR 0034） |

### どこでも効く決まり

- ViewModel は `@Observable`・`@MainActor` の class。1 画面に 1 つ。Repository は `init` で受け取る。Repository の呼び出しは `async throws` で、エラーは ViewModel で受け止め、再試行できるように見せる。
- **1 ファイル 1 型。ファイル名 = 型名。**
- Bool の名前は `is` / `has` / `can` で始める。非同期の関数は動詞で始める。プロトコルは役割を表す名前（`SessionRepositoryProtocol`）。enum は単数形で、case は lowerCamelCase。
- シートは `RootView` に 1 つだけ置き、出すときは必ず `present()` を通す（ADR 0025・0032、`docs/v1_navigation_songs_recording.md`）。
- iOS 17 の不具合から来たパターン（気分での絞り込みをメモリで行う ADR 0007、シートを 1 つにする ADR 0008）は今も有効。変えるときは新しい ADR を足す。

---

## Git の決まり

- **ブランチ名**：`{種類}/{英語の短い名前}`。Issue 番号は付けない（例：`feature/after-save-recommendation`、`fix/data-load-error`）。種類は `feature` / `fix` / `refactor` / `docs` / `chore`。1 つの Issue（1 スプリント）に 1 ブランチ。どのブランチも、終わった時点でアプリが動く状態にする。
- **Issue とのつながり**：コミットメッセージに `Refs #N`、PR の本文に `Closes #N`。
- **コミットメッセージ**：`{プレフィックス}: {50 文字以内の要約}` を日本語で。必要なら本文に「何を」「なぜ」を書く。プレフィックスは `feat:` / `fix:` / `refactor:` / `docs:` / `test:` / `chore:`。
- **マージ**：PR を squash merge で `main` に入れる。`main` に直接 push しない。

---

## プロジェクトの制約（憲法）

[docs/constitution.md](docs/constitution.md) の要点。憲法は ADR やほかの文書より優先される。

- **外部の曲データ（Spotify など）は今は使っていない。** 使うときは識別子（`spotifyTrackId` など）だけを永続化し、曲名・アーティスト名・アートワークなどのメタデータは永続化しない。認証・キャッシュ・クレジット表記は、そのときに ADR で決める。
- **SwiftData が唯一の正（SSOT）。** オフラインファースト：記録と履歴はネットワークがなくても動く。気分やメモは端末の外に出さない。
- **`Track` と `SingingSession` を分ける**：重複をまとめるのは曲だけ。記録は歌うたびに新しく作る。
- タスクと仕様の変更は GitHub Issues、設計の判断は `docs/adr/`（1 件 1 ファイル。承認した本文は書き換えず、新しい番号で置き換える）。`docs/archive/` は止まった過去の資料。

---

## 関連するファイル

- docs/constitution.md — プロジェクトの最上位のルール
- docs/adr/ — 技術判断の記録。書き方は docs/adr/README.md
- docs/README.md — docs の目次と、どれが正か
- .claude/rules/ — フォルダごとの決まり（SwiftData・Presentation・テスト）
- .claude/skills/karaoke-review/ — このプロジェクト用のコードレビュー
