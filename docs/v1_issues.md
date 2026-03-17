# V1 Issue 一覧（タスク統合版）

**Version**: 1.1  
**Created**: 2026-03-14  
**Updated**: 2026-03-14（V2移行レビュー反映、技術選定の明文化）  
**前提フロー**: 曲入力 → Intent → スコア → 履歴 → ランキング

> **ドキュメントの位置づけ**: 本ファイルは V1 向け Issue/タスク体系の**単一の信頼できるソース（Source of Truth）**です。  
> `docs/issues.md` および `docs/issues_with_tasks.md` は全フェーズ（Phase 0〜4）の Issue 一覧を保持しますが、**V1 の範囲（I-001〜I-018 等）では本ファイルを正として参照**してください。  
> V1 関連の内容を更新する場合は、本ファイルを先に更新し、必要に応じて `issues_with_tasks.md` へ反映する運用とします。

---

## 技術選定メモ（V2移行を見据えた方針）

| 項目 | 選定 | 理由 |
|------|------|------|
| **DI 注入方法** | `@Environment` + カスタム EnvironmentKey | 憲法の「環境に注入」に準拠。EnvironmentKey は App 層に定義し、Data 層は SwiftUI に依存しない。Repository ごとに Key を切ることで、V2 で TrackMetadataService 等を追加する際に Key を追加するだけで済む。Protocol 型の注入も EnvironmentKey で対応可能。 |
| **TabView + NavigationStack** | 各タブごとに独立した NavigationStack | iOS 17+ のベストプラクティス。TabView 内側に NavigationStack を配置することで、タブ切り替え時もタブバーが表示され続ける。各タブのナビ履歴が独立し、V2 で検索タブ等を追加しても影響が局所化される。 |
| **選曲結果の受け渡し** | `navigationDestination(for: SelectedTrack.self)` で value を渡す | 型安全で、V2 の検索・Spotify 履歴からの選曲も同じ型で扱える。Hashable にすれば NavigationPath と相性が良い。 |
| **エラー表示** | 共通コンポーネント（メッセージ + 再試行ボタン） | I-009（保存失敗）と I-030（API エラー）で同じ UI を再利用。文言・挙動の統一と V2 での拡張を容易にする。 |

---

## 実装順序（推奨）

```
Phase 0: I-001 → I-002 → I-006 → I-003 → I-004 → I-005
Phase 1: I-007 → I-007A → I-012 → I-008 → I-009 → I-010 → I-011 → I-013 → I-014 → I-015 → I-016
Phase 2: I-017 → I-018
```

---

## Phase 0: 基盤構築

### [I-001] プロジェクト初期化 ✅
- **依存**: なし
- **Labels**: `priority:must`, `type:chore`, `phase:0-基盤`
- **Tasks**:
  - [x] Xcodeで新規iOSプロジェクトを作成する（iOS 17+、Swift 5.9）
  - [x] SwiftUIを選択し、不要なデフォルトファイル（ContentView等）を整理する
  - [x] フォルダ構成の雛形を作成する（Sources/Presentation/Domain/Data のレイヤー構成）
  - [x] Info.plist / プロジェクト設定で最低デプロイメントターゲットを iOS 17.0 に設定する

---

### [I-002] SwiftDataモデル定義 ✅
- **依存**: I-001
- **Labels**: `priority:must`, `type:feat`, `phase:0-基盤`
- **Tasks**:
  - [x] Track エンティティを @Model で定義する（id, spotifyTrackId, userEnteredName, singCount, latestScore, createdAt, updatedAt）
  - [x] SingingSession エンティティを @Model で定義する（id, track, intent, performedAt, score, memo）
  - [x] Intent エンティティを enum で定義する（shout, emo, practice）
  - [x] Track と SingingSession のリレーション（1:N、cascade削除）を設定する
  - [x] ModelContainer をアプリエントリポイントで初期化し、SwiftData スキーマを登録する

---

### [I-006] ネットワーク監視ユーティリティ ✅
- **依存**: I-001
- **Labels**: `priority:must`, `type:feat`, `phase:0-基盤`
- **Tasks**:
  - [x] NWPathMonitor を用いた NetworkMonitor クラス/構造体を作成する
  - [x] 接続状態（online/offline）を @Published、AsyncStream、または @Observable で公開する
  - [x] アプリ起動時に監視を開始し、状態変化を検知できるようにする
  - [x] @Environment(\.networkMonitor) で参照できるよう EnvironmentKey を定義し、App 起点で注入する（I-012 等でオフライン判定に使用）
  - [x] NetworkMonitor に @MainActor を付与し、pathUpdateHandler 内で Task { @MainActor in } により isOnline をメインスレッドで更新する（Swift 6 厳格並行性対応）
  - [x] EnvironmentKey を App 層（NetworkMonitorEnvironment.swift）に配置し、Data 層は SwiftUI に依存しない（レイヤー設計準拠）

---

### [I-003] SessionRepository 実装 ✅ 
- **依存**: I-002
- **Labels**: `priority:must`, `type:feat`, `phase:0-基盤`
- **Tasks**:
  - [x] SessionRepository プロトコル（インターフェース）を Domain/Repositories に定義する
  - [x] SwiftDataSessionRepository を Data/SwiftData に実装する
  - [x] save(session) メソッドを実装する（SwiftData insert）
  - [x] fetchAll(limit, offset) を実装する（日時降順）。offset はスキップ件数（0-based）。例: limit=20, offset=0 で 1〜20 件目、offset=20 で 21〜40 件目
  - [x] fetchByIntent(intent) を実装する
  - [x] exists(uuid) を実装する（冪等性チェック用）

---

### [I-004] TrackRepository 実装 ✅
- **依存**: I-002
- **Labels**: `priority:must`, `type:feat`, `phase:0-基盤`
- **Tasks**:
  - [x] TrackRepository プロトコルを Domain/Repositories に定義する
  - [x] SwiftDataTrackRepository を Data/SwiftData に実装する
  - [x] searchLocal(query) を実装する（userEnteredName に対する predicate、歌った回数降順）
  - [x] getOrCreate(spotifyTrackId?, userEnteredName?) を実装する（既存検索 or 新規作成）。両方 nil の場合は throw で呼び出し側にエラーを返す（手動入力の空文字は I-012 でバリデーションするため、Repository には渡らない想定）
  - [x] incrementSingCount(trackId) を実装する（集計更新）
  - [x] 同一曲の2回目以降は既存 Track を返し、SingingSession のみ追加するロジックを確認する

---

### [I-005] InsightRepository 実装
- **依存**: I-002
- **Labels**: `priority:must`, `type:feat`, `phase:0-基盤`
- **Tasks**:
  - [ ] InsightRepository プロトコルを Domain/Repositories に定義する
  - [ ] SwiftDataInsightRepository を Data/SwiftData に実装する
  - [ ] getTimeMachineRanking() を実装する（過去1ヶ月、歌唱回数降順）
  - [ ] getMyAnthemRanking() を実装する（Intent別の回数・点数ランキング）
  - [ ] SwiftData の @Query または FetchDescriptor で集計クエリを実装する

---

## Phase 1: タブ・曲入力〜保存

### [I-007] タブナビゲーション基盤
- **依存**: I-001
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] TabView で選曲画面（2タブ）、History、設定の3タブを構成する。各タブ内に独立した NavigationStack を配置する（タブバーが常に表示され、各タブのナビ履歴が独立する構成）
  - [ ] タブA: インテント、タブB: Spotify視聴履歴のセグメント/タブUIを配置する。V1 ではタブB・設定は `EmptyPlaceholderView` 等の共通プレースホルダーを使用し、V2 で同型の View に差し替える
  - [ ] History 画面への遷移をタブバーに追加する
  - [ ] 設定画面への遷移をタブバーに追加する

---

### [I-007A] 依存性注入（DI）接続
- **依存**: I-002, I-003, I-004, I-005, I-007
- **Labels**: `priority:must`, `type:chore`, `phase:1-MVP`
- **Tasks**:
  - [ ] App エントリで ModelContainer を参照（I-002 で登録済みの場合は確認のみ）
  - [ ] SessionRepository / TrackRepository / InsightRepository の具体実装を生成する
  - [ ] @Environment に統一。EnvironmentKey は App 層に定義し（例: `\.sessionRepository`, `\.trackRepository`, `\.insightRepository`。※ Swift の KeyPath 記法はバックスラッシュ 1 つ）、ルート View に `.environment(\.sessionRepository, impl)` で渡す
  - [ ] 各 ViewModel が View 経由で @Environment から Repository を取得し、初期化引数で受け取る形で接続する
- **DoD**: 歌唱記録フロー（I-013）で RecordingViewModel が @Environment から SessionRepository / TrackRepository を取得し、保存処理が動作すること

---

### [I-012] 手動曲名入力画面
- **依存**: I-006, I-007
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] 曲名入力用の TextField を実装する
  - [ ] 曲名が空文字の場合は Intent 選択へ遷移しない。バリデーションで「曲名を入力してください」等を表示する（getOrCreate に両方 nil を渡さないため）
  - [ ] オフライン時に「ネットワークに接続してください」メッセージを表示する（ブロックはしない）。@Environment(\.networkMonitor) で接続状態を参照する
  - [ ] 接続への導線（設定画面へのリンク、リトライボタン）を配置する
  - [ ] 入力した曲名を `SelectedTrack(spotifyTrackId: nil, userEnteredName: 入力値)` として、`navigationDestination(for: SelectedTrack.self)` で Intent 選択画面へ渡す

---

### [I-008] Intent選択画面
- **依存**: I-007
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] Shout / Emo / Practice の3択UIを実装する（ボタン or セグメント）
  - [ ] 選択状態を ViewModel で保持し、歌唱記録フローに渡す
  - [ ] 選曲結果（SelectedTrack）を受け取り、歌唱記録入力画面へ渡す
  - [ ] 選択後に歌唱記録入力画面へ遷移するナビゲーションを実装する

---

### [I-009] 歌唱記録入力画面
- **依存**: I-003, I-004, I-007, I-007A
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] スコア入力UI（0〜100）を実装する（Slider または Stepper）
  - [ ] メモ入力UI（任意、TextField）を実装する
  - [ ] 保存ボタンを配置し、RecordingViewModel 経由で TrackRepository.getOrCreate → SessionRepository.save を実行する
  - [ ] 保存成功時は `selectedTab = .history` で履歴タブへ切り替える
  - [ ] 保存失敗時は共通エラー表示コンポーネント（メッセージ「保存に失敗しました。もう一度お試しください」+ 再試行ボタン）を使用する。Alert またはインライン表示。V2 の I-030（API エラー）でも再利用する

---

### [I-010] 二重送信防止（UI層）
- **依存**: I-009
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] 保存ボタンタップ後に即座にボタンを非活性化する
  - [ ] 保存処理中に ProgressView を表示する
  - [ ] 処理完了まで画面のインタラクションをブロックする（オーバーレイ等）
  - [ ] 完了後にボタンを復帰させる

---

### [I-011] 二重送信防止（データ層）
- **依存**: I-003, I-009
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] 保存前に SessionRepository.exists(uuid) で重複チェックを行う
  - [ ] 既存の場合はスキップし、二重登録を防止する
  - [ ] クライアント生成の UUID を Idempotency Key として使用する
  - [ ] 冪等性が保証されることを確認する

---

### [I-013] 歌唱記録フロー統合
- **依存**: I-004, I-008, I-009, I-010, I-011, I-012
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] 選曲結果の受け渡し型 `SelectedTrack` を定義する。`spotifyTrackId: String?` と `userEnteredName: String?` を持ち、少なくとも片方が非空であること。Hashable にして navigationDestination で渡す。V2 で検索・Spotify 履歴からの選曲も同じ型で扱う
  - [ ] 曲選択（手動入力 or ランキングタップ）→ Intent選択 → 歌唱記録入力 → 保存の一連フローを接続する
  - [ ] RecordingViewModel で TrackRepository.getOrCreate で Track を取得/作成し、SessionRepository.save で SingingSession を保存する
  - [ ] ナビゲーション方針: 選曲タブ内は NavigationStack + NavigationPath。保存成功時は selectedTab = .history でタブ切り替え。docs/ またはコード内コメントに遷移図を残す
  - [ ] フロー全体のナビゲーションと状態遷移を確認する

---

## Phase 1: 履歴・Empty・ランキング

### [I-014] History画面
- **依存**: I-003, I-007
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] 歌唱セッションを日時降順で一覧表示する List を実装する
  - [ ] Intent フィルター（Shout/Emo/Practice）を画面上部に配置する
  - [ ] V1 では `track.userEnteredName ?? "不明"` で曲名を表示する。V2 で TrackMetadataCache 経由に切り替える際は、曲名取得ロジックをヘルパー化しておくと変更が局所化される
  - [ ] セッション行をタップした場合のアクション（V1では未実装で可）

---

### [I-015] Infinite Scroll
- **依存**: I-014
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] fetchAll(limit: 20, offset) を用いたページネーションを実装する。offset = pageIndex * 20（0-based）。I-003 の offset 仕様に準拠
  - [ ] スクロール末尾で追加読み込みをトリガーする
  - [ ] 大量データ（1000件以上）でもメモリ消費を抑制する
  - [ ] ローディングインジケータを表示する

---

### [I-016] Empty State（歌唱0件）
- **依存**: I-005, I-007
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] 歌唱データ0件時に「まず1曲歌ってみよう！」メッセージを表示する
  - [ ] 「手動で曲名を入力して歌う」への導線を NavigationLink または Button で配置する。タップで手動曲名入力画面へ遷移
  - [ ] Empty State 用の再利用可能な View コンポーネントとして実装する。I-017 のインテントタブがデータ0件時にこれを表示する

---

## Phase 2: インサイト・検索

### [I-017] インテントタブUI
- **依存**: I-005, I-007, I-016
- **Labels**: `priority:must`, `type:feat`, `phase:2-インサイト`
- **Tasks**:
  - [ ] タイムマシン表示領域をレイアウトする
  - [ ] マイアンセム表示領域をレイアウトする
  - [ ] InsightRepository からデータを取得する ViewModel を用意する
  - [ ] 歌唱データ0件時は I-016 の Empty State コンポーネントを表示する

---

### [I-018] タイムマシン表示
- **依存**: I-005, I-017
- **Labels**: `priority:must`, `type:feat`, `phase:2-インサイト`
- **Tasks**:
  - [ ] getTimeMachineRanking() で過去1ヶ月のランキングを取得する
  - [ ] 歌った回数降順でリスト表示する
  - [ ] V1 では `track.userEnteredName ?? "不明"` で曲名を表示する
  - [ ] ランキング内の曲をタップすると `SelectedTrack(spotifyTrackId: track.spotifyTrackId, userEnteredName: track.userEnteredName)` を navigationDestination で渡し、歌唱記録フローへ遷移する

---

## V1 完了判定チェックリスト

| # | 検証項目 | 完了 |
|---|----------|------|
| 1 | アプリ起動時にタブバーに「選曲」「履歴」「設定」が表示される | □ |
| 2 | 選曲タブがデフォルトで表示される | □ |
| 3 | 歌唱0件時、インテントタブに「まず1曲歌ってみよう！」が表示される | □ |
| 4 | 「手動で曲名を入力して歌う」等の導線がある | □ |
| 5 | 手動曲名入力画面で曲名を入力し、Intent選択へ遷移できる | □ |
| 6 | オフライン時はメッセージが表示される（ブロックはしない） | □ |
| 7 | 曲入力後に Shout / Emo / Practice の3択が表示される | □ |
| 8 | Intent選択後に歌唱記録入力画面へ遷移する | □ |
| 9 | スコア（0〜100）とメモを入力し、保存できる | □ |
| 10 | 保存中はボタン非活性・ProgressView 表示される | □ |
| 11 | 二重タップで重複保存されない | □ |
| 12 | 保存成功時に履歴タブへ遷移する | □ |
| 13 | 保存失敗時にエラー表示・再試行ができる | □ |
| 14 | 履歴が日時降順で一覧表示される | □ |
| 15 | Intent フィルターが動作する | □ |
| 16 | 20件ごとの追加読み込みが動作する | □ |
| 17 | 歌唱1件以上で、インテントタブにタイムマシンランキングが表示される | □ |
| 18 | ランキング内の曲をタップすると歌唱記録フローへ遷移する | □ |
| 19 | 曲選択 → Intent → スコア → 保存 → 履歴 が一連で動作する | □ |
