# ヒトカラモバイルiOS

> Spotify 連携 × オフラインファースト — 一人カラオケの記録・振り返りを支援する iOS ネイティブアプリ

---

## 📝 概要

### アプリの目的

日々の「ヒトカラ（一人カラオケ）」の歌唱記録・振り返りを効率化する iOS アプリケーション。Spotify 単体では提供できない **ユーザーの感情・文脈（Intent）** に基づいた独自インサイトをローカルで生成し、次なる選曲のトリガーとして提供する。

### 解決する課題

- カラオケボックスは地下にあることが多く**通信環境が不安定** → 体験が劣化しない **オフラインファースト** 設計
- Spotify には「どんな気持ちで歌ったか」というメタデータがない → **Intent（Shout / Emo / Practice）** による感情ラベリングと独自ランキング
- 歌唱記録が散逸しがち → **ローカル DB（SwiftData）** による永続化と、タイムマシン・マイアンセムによる振り返り

### ターゲットユーザー

一人カラオケを定期的に楽しむユーザー（日本語環境・iPhone 利用者）

---

## 📱 アプリ概要（UI/UX）

### 主要画面

| 画面 ID | 画面名 | 役割 |
|---------|--------|------|
| S-002 | 選曲・ホーム | **V1**: インテントのみ（タイムマシン / マイアンセム）。セグメントなし。**V2** 予定: Spotify 視聴履歴を切替（`basic_design` のタブ A/B） |
| S-003 | 検索 | ハイブリッド検索（ローカル優先 + Spotify API）（V2） |
| S-004/005 | 歌唱記録シート | **1 枚のシート**で完結。上から **曲入力 → スコア（0〜100）→ Intent（Shout/Emo/Practice）→ 歌唱日時 → メモ（任意）→ 保存**（`RecordingSheetContentView`） |
| S-006 | History | 日時降順一覧、Intent フィルター、ソート、Infinite Scroll、スワイプ削除・編集 |
| S-007 | 設定 | Spotify 連携状態、リフレッシュ（V2） |

### ユーザーフロー

```
曲選択（ランキングタップ or 手動入力）
    ↓ .sheet(item:)
同一シート内（スクロール順）:
  曲入力 → スコア（Slider 0〜100）→ Intent（🔥 Shout / 🌙 Emo / 🎤 Practice）
    → 歌唱日時 → メモ（任意）
    ↓
保存（二重送信防止 → 冪等保存）
    ↓ selectedTab = .history
履歴タブへ自動遷移 + シート解除
```

---

## 🏗 アーキテクチャ

### 採用設計: レイヤードアーキテクチャ + MVVM + Repository パターン

```
Presentation ─依存→ Domain Protocol ←実装─ Data
```

| レイヤー | 責務 | SwiftUI 依存 |
|----------|------|--------------|
| **Presentation** | View（描画専用）+ ViewModel（`@Observable`・`@MainActor`） | ✅ |
| **Domain** | Protocol 定義・Model 定義・ヘルパー。外部 FW 非依存が原則 | ❌（※ @Model のみ例外許容） |
| **Data** | SwiftData / Spotify API / Cache の具体実装 | ❌ |
| **App** | `@main` エントリ、DI 組み立て、EnvironmentKey 定義 | ✅ |

### 技術選定の理由

| 技術 | 選定理由 |
|------|----------|
| **SwiftUI** | 宣言的 UI で状態管理が明確。iOS 17+ で SwiftData と統合しやすい |
| **SwiftData** | iOS 17+ ネイティブ ORM。Track 1:N SingingSession の単純なリレーションに十分。サードパーティ非依存 |
| **`@Observable`（iOS 17+）** | `@StateObject` / `@ObservedObject` を不要にし、ViewModel の記述を簡潔化 |
| **Repository パターン** | SSOT（Single Source of Truth）をローカル DB に限定し、オフラインファーストを実現 |
| **手動 DI（`@Environment`）** | DI ライブラリを使わず、EnvironmentKey でプロトコル型を注入。テスト時にモック差し替え可能 |
| **URLSession** | Spotify REST API 呼び出しに十分。Alamofire 等は過剰 |
| **OAuth 2.0 PKCE** | Spotify Web API の推奨方式。Keychain にトークン保存 |

---

## 🔄 データフロー

### 歌唱セッション保存（オンライン）

```
User → View（ボタン非活性化 + ProgressView）
   → ViewModel.save()
   → TrackRepository.getOrCreate()     // Track の取得 or 新規作成
   → SessionRepository.saveNewRecordingSession()
       ├─ exists(uuid)? → true: スキップ（冪等）
       └─ false: insert + Track.singCount += 1
   → 完了 → 履歴タブ遷移 + シート解除
```

### 歌唱セッション保存（オフライン）

```
User → View → ViewModel.save()
   → Track(userEnteredName: "曲名") で手動入力曲を生成
   → SwiftData に insert（Spotify メタデータなし）
   → エラーを出さずに保存完了
```

### Spotify メタデータ取得（V2 以降）

```
Track.spotifyTrackId → TrackMetadataCache（actor ベース・24h TTL）
    ├─ キャッシュヒット → TrackMetadata を返却
    └─ ミス → Spotify API → キャッシュ更新 → 返却
    ※ メタデータの永続保存は Spotify API 規約で禁止
```

---

## 🧩 技術的な設計

### 状態管理

| 仕組み | 用途 |
|--------|------|
| `@Observable` + `@MainActor` | ViewModel の状態保持。1 画面 1 ViewModel |
| `@State` | View 内の一時 UI 状態、ViewModel インスタンスの保持 |
| `@Binding` | 親→子の双方向バインディング |
| `@Environment` | Repository・NetworkMonitor・テーマ等のアプリ全体共有 |
| `loadGeneration` カウンタ | 非同期完了の交差による古いデータの上書きを防止（`HistoryViewModel`・`IntentTabViewModel`） |

### 非同期処理

- **`async throws`** を基本とする構造化並行性（Swift Concurrency）
- Repository・ViewModel とも `@MainActor` で ModelContext のスレッド安全性を保証
- `Task.checkCancellation()` によるキャンセル伝播
- V2 以降: `actor TrackMetadataCache` でスレッドセーフなキャッシュアクセス

### データ管理

| 永続化 | 対象 |
|--------|------|
| **SwiftData（SSOT）** | Track（`spotifyTrackId`, `userEnteredName`, `singCount`, `latestScore`）、SingingSession（`intent`, `score`, `memo`, `performedAt`） |
| **インメモリ TTL キャッシュ（24h）** | Spotify メタデータ（曲名・アーティスト名・アートワーク）— 永続化禁止 |
| **Keychain** | OAuth トークン |
| **UserDefaults** | チュートリアル表示フラグ等の UI 設定のみ |

### 冪等性・二重送信防止

- **データ層**: クライアント生成 UUID を Idempotency Key として `exists(uuid)` チェック → 既存なら insert / singCount 加算をスキップ
- **UI 層**: 保存ボタン即時非活性化 + ProgressView + インタラクションブロック

### オフラインファースト

- `NWPathMonitor` ベースの `NetworkMonitor`（`@Observable`）で接続状態を監視
- オフライン時: `Track(userEnteredName:)` でローカル保存。ブロックせず継続
- オンライン復帰時: `spotifyTrackId` による Spotify API でのメタデータ補完のみ（外部サーバー同期なし）

---

## 📂 ディレクトリ構成

```
Sources/
├── App/                          # @main エントリポイント、EnvironmentKey（DI 配線）
│   ├── KaraokeSupportApp.swift   # ModelContainer 生成、Repository 注入
│   ├── *RepositoryEnvironment.swift  # 各 Repository の EnvironmentKey
│   ├── Preview*Repository.swift  # プレビュー用モック
│   ├── NetworkMonitorEnvironment.swift
│   └── ManualRecordingNavigationEnvironment.swift
│
├── Presentation/                 # View + ViewModel（画面単位でサブフォルダ）
│   ├── Recording/                # 歌唱記録シート（曲入力 → スコア → Intent → メモ + 保存）
│   ├── History/                  # 履歴一覧（フィルター・ソート・ページネーション・削除・編集）
│   ├── Songs/                    # 選曲ルート・インテントタブ（タイムマシン・マイアンセム、`NavigationStack` + `.sheet`）
│   ├── Insight/                  # 現状はプレースホルダー（`.gitkeep`）。将来の拡張用
│   ├── Search/                   # ハイブリッド検索（V2・現状 `.gitkeep`）
│   ├── Settings/                 # 設定画面（プレースホルダー、V2 で本実装）
│   ├── Root/                     # RootView（TabView）
│   ├── Common/                   # 共通コンポーネント（Empty State 等）
│   └── Theme/                    # AppColor（セマンティック色トークン）
│
├── Domain/                       # Protocol 定義・モデル（フレームワーク非依存が原則）
│   ├── Models/
│   │   ├── SwiftData/            # Track, SingingSession（@Model）
│   │   ├── Enums/                # Intent
│   │   ├── Flow/                 # SelectedTrack, RecordingDraft
│   │   └── Rankings/             # InsightTrackCountRanking, MyAnthemRanking 等
│   ├── Repositories/             # SessionRepositoryProtocol, TrackRepositoryProtocol, InsightRepositoryProtocol
│   └── Helpers/                  # TrackDisplayTitle
│
└── Data/                         # 具体実装（SwiftData, Spotify, Cache）
    ├── SwiftData/                # SwiftDataSessionRepository, SwiftDataTrackRepository, SwiftDataInsightRepository
    ├── Network/                  # NetworkMonitor（NWPathMonitor）
    ├── Spotify/                  # V2 用（現状 `.gitkeep`）。SpotifyAPIClient 等を配置予定
    └── Cache/                    # V2 用（現状 `.gitkeep`）。TrackMetadataCache を配置予定
```

### テストディレクトリ

```
Karaoke_supportTests/             # 14 ユニットテストファイル
Karaoke_supportUITests/           # UIテスト（LaunchTests）
```

---

## 🧭 開発プロセス（Spec 駆動）

### Spec → Issue → 実装 の流れ

本プロジェクトでは **SpecKit** によるスペック駆動開発を採用し、以下のフローで開発を進めた。

```
1. 要求仕様書（raw_spec.md）を作成
     ↓
2. SpecKit で Feature Specification（spec.md）を生成
   - User Story / Acceptance Scenario / Functional Requirements を定義
     ↓
3. 基本設計書（basic_design.md）・詳細設計書（detailed_design.md）を作成
   - 画面遷移図・シーケンス図・クラス図・ER 図を Mermaid で記述
     ↓
4. Issue 設計（`docs/issues.md` → **`docs/v1_issues.md`（V1 の正）**）で実装タスクに分解
   - Phase 0（基盤）→ Phase 1（MVP）→ Phase 2（インサイト）→ Phase 3/4（Spotify 連携・品質）
   - **番号の対応**: 全フェーズ一覧は `issues.md`、V1 スコープの分解・完了チェックは **`v1_issues.md`** を参照（同一 Issue でも文言が V1 に寄せてある場合あり）
     ↓
5. クロスチェックレポート（cross_check_report.md）でドキュメント間の矛盾・抜け漏れを**手動で棚卸し**し修正
     ↓
6. 1 Issue 1 ブランチで実装 → PR → squash merge
     ↓
7. 各 Issue に対応する feature log（log/feature/i-xxx-*/）で実装記録を残す
```

### SpecKit の活用方法

- **`.specify/memory/constitution.md`**: プロジェクトの憲法（最上位ルール）として Core Principles / Architecture Rules / Governance を定義。すべての設計・実装文書はこれに従う
- **`.specify/templates/`**: spec / plan / checklist / tasks の標準テンプレートを用意し、ドキュメントのフォーマットを統一
- **仕様の分解**: Functional Requirements（FR-001〜FR-020）→ Issue（I-001〜I-039）→ タスクチェックリスト の 3 段階で分解

### SpecKit による設計のメリット

1. **認識統一**: 仕様書・設計書・Issue を相互参照し、ドキュメント間の矛盾を排除（`cross_check_report.md` で棚卸し。CI による自動検証は未導入）
2. **抜け漏れ防止**: FR → Issue の対応表を維持し、実装漏れを防止
3. **依存関係の可視化**: Mermaid で Issue 間のブロック関係を図示し、並列着手可能なタスクを識別

---

## 🔗 Spec / Issue / 実装の対応関係

### Phase 0: 基盤構築（全 ✅ 実装済み）

| Issue | 対応 FR | 実装ファイル（主要） | ユニットテスト |
|-------|---------|---------------------|----------------|
| I-001 プロジェクト初期化 | — | プロジェクト構成一式 | — |
| I-002 SwiftData モデル定義 | FR-001, FR-010, FR-017 | `Track.swift`, `SingingSession.swift`, `Intent.swift` | — |
| I-003 SessionRepository | FR-001, FR-013 | `SessionRepositoryProtocol.swift`, `SwiftDataSessionRepository.swift` | `SwiftDataSessionRepository*Tests.swift`（4 ファイル） |
| I-004 TrackRepository | FR-010 | `TrackRepositoryProtocol.swift`, `SwiftDataTrackRepository.swift` | — |
| I-005 InsightRepository | FR-004 | `InsightRepositoryProtocol.swift`, `SwiftDataInsightRepository.swift` | — |
| I-006 NetworkMonitor | FR-008, FR-012 | `NetworkMonitor.swift`, `NetworkMonitorEnvironment.swift` | — |

### Phase 1: MVP（全 ✅ 実装済み）

| Issue | 対応 FR | 実装ファイル（主要） | ユニットテスト |
|-------|---------|---------------------|----------------|
| I-007 タブナビゲーション | FR-006 | `RootView.swift`, `SongsRootView.swift` | — |
| I-007A DI 接続 | — | `*RepositoryEnvironment.swift`（5 ファイル） | — |
| I-008 Intent 選択 | FR-003 | `RecordingSheetContentView.swift` 内の Intent セクション | — |
| I-009 歌唱記録入力 | FR-001, FR-002, FR-011 | `RecordingSheetContentView.swift`, `RecordingSheetViewModel.swift` | `RecordingSheetViewModelEditSaveTests.swift` |
| I-010 二重送信防止（UI 層） | FR-013 | `RecordingSheetContentView.swift`（ボタン非活性 + ProgressView） | — |
| I-011 二重送信防止（データ層） | FR-013 | `SwiftDataSessionRepository.saveNewRecordingSession()` | `I011SessionIdempotencyTests.swift` |
| I-012 手動曲名入力 | FR-007, FR-008, FR-009 | `RecordingSheetContentView.swift` 内の手動入力セクション | — |
| I-013 歌唱記録フロー統合 | FR-001〜FR-003 | `SongsRecordingRoute.swift`, `RecordingSheetContainerView.swift` | — |
| I-014 History 画面 | FR-006 | `HistoryRootView.swift`, `HistoryListView.swift`, `HistoryViewModel.swift` 他 11 ファイル | `HistoryViewModel*Tests.swift`（3 ファイル）, `HistorySortOrderTests.swift` |
| I-014-A 色・テーマ | — | `AppColor`（Asset Catalog）, `color_tokens_v1.md` | — |
| I-014-B ソート | — | `HistorySortOrder.swift`, `HistorySortControlView.swift` | `HistorySortOrderTests.swift` |
| I-014-C 履歴からの編集 | — | `RecordingSheetViewModel.swift`（編集モード分岐） | `RecordingSheetViewModelEditSaveTests.swift` |
| I-015 Infinite Scroll | — | `HistoryViewModel.loadNextPageIfNeeded()`, `shouldPrefetch()` | `HistoryViewModelPaginationTests.swift` |
| I-016 Empty State | — | `SingingEmptyStateView.swift`, `SingingEmptyStateCopy.swift` | `SingingEmptyStateCopyTests.swift` |

### Phase 2: インサイト（全 ✅ 実装済み）

| Issue | 対応 FR | 実装ファイル（主要） | ユニットテスト |
|-------|---------|---------------------|----------------|
| I-017 インテントタブ UI | FR-004 | `IntentTabContainerView.swift`, `IntentTabViewModel.swift`, ランキング関連 View | `IntentTabViewModelTests.swift`, `InsightTrackRowTitleTests.swift` |
| I-018 タイムマシン表示 | FR-004 | `TimeMachineRankingSheetView.swift`（I-017 に統合） | `IntentTabViewModelTests.swift` |

---

## 🤖 AI 開発ルール（.cursorrules）

### 定義したルールの概要

`.cursorrules`（132 行）で以下の 3 分野のルールを定義し、Cursor（AI コーディングアシスタント）への指示を体系化した。

#### 1. SwiftUI と SwiftData のコーディング憲法（§1）

| ルール | 内容 |
|--------|------|
| View とロジックの分離 | View は描画専用。Repository 呼び出し・非同期処理は ViewModel に委譲 |
| `@Observable` + `@MainActor` | iOS 17+ では `@Observable`。`@StateObject` / `@ObservedObject` は使わない |
| 1 画面 1 ViewModel | 画面ごとに 1 つの ViewModel を割り当て |
| Repository は注入（DI） | ViewModel は Repository を初期化時に受け取る。`@Environment` 経由 |
| EnvironmentKey は App 層 | Data 層は SwiftUI に依存しない |
| SSOT はローカル DB | API レスポンスを直接 View に渡さない。Spotify メタデータの永続化禁止 |
| `async throws` | Repository の非同期メソッドは `async throws` を基本とする |
| ModelContext のスレッド管理 | Repository には `@MainActor` を付与し、メインスレッドでアクセス |

#### 2. 命名規則（§2）

| 対象 | ルール | 実装例 |
|------|--------|--------|
| ファイル | 1 ファイル 1 型、ファイル名 = 型名 | `HistoryViewModel.swift` → `class HistoryViewModel` |
| ディレクトリ | レイヤー配下に機能単位のサブディレクトリ | `Presentation/History/`, `Data/SwiftData/` |
| データモデル | 単数形・PascalCase、Bool は `is`/`has`/`can` | `Track`, `SingingSession` |
| 関数 | 動詞で始める。Repository: `save`/`fetch`/`delete` | `saveNewRecordingSession()`, `fetchAll()` |
| #Preview | 可能な View には必ず `#Preview` を用意 | 各 View ファイル末尾に記載 |

#### 3. Git ブランチ戦略・コミットルール（§3）

| ルール | 内容 |
|--------|------|
| 1 Issue 1 ブランチ | `{issue番号}-{機能名}` |
| コミットメッセージ | `feat:` / `fix:` / `refactor:` / `docs:` / `test:` / `chore:` プレフィックス。50 文字以内 |
| マージ | PR 経由、squash merge 推奨 |

### AI 活用方法

- `.cursorrules` を Cursor のプロジェクトルールとして読み込ませ、コード生成・リファクタリング時の**プロンプトに一貫した制約**を与える
- `.specify/memory/constitution.md` を最上位ルールとしてプロンプトに含め、**人間がレビューしやすい形**で出力を揃える（**自動 CI で憲法違反を検証しているわけではない**）
- SpecKit テンプレート（`.specify/templates/`）を用いて、仕様書・Issue の生成を標準化

### コード品質への影響

- 全 ViewModel が `@Observable` + `@MainActor` で統一（`@StateObject` の使用はゼロ）
- 全 Repository が Protocol + 具体実装の分離（DI / テスタブル）
- 命名規則が全ファイルで一貫（ファイル名 = 型名）

### 実装との整合性

| ルール | 遵守状況 |
|--------|----------|
| View とロジックの分離 | ✅ 実装済み全 View で遵守。View 内に Repository 呼び出しなし |
| `@Observable` + `@MainActor` | ✅ `HistoryViewModel`, `IntentTabViewModel`, `RecordingSheetViewModel` 等すべてで適用 |
| 1 画面 1 ViewModel | ✅ 遵守 |
| Repository は DI | ✅ `@Environment` → ViewModel init で注入 |
| EnvironmentKey は App 層 | ✅ `Sources/App/` に全 EnvironmentKey を配置 |
| SSOT はローカル DB | ✅ メタデータ永続化なし。SwiftData が唯一の真実 |
| 1 ファイル 1 型 | ✅ 遵守 |
| `async throws` | ✅ 全 Repository メソッドで適用 |
| `#Preview` | ✅ 原則として View に `#Preview` を付与（プレビュー不可な条件は `.cursorrules` に準拠） |
| 強制アンラップ禁止 | ✅ `guard let` / `if let` を使用。`precondition` は固定リテラルのみ |

---

## ✅ 実装済み機能（V1 — Phase 0〜2 完了）

- [x] SwiftData モデル定義（Track 1:N SingingSession、Intent enum）
- [x] SessionRepository（保存・更新・削除・検索・冪等性チェック）
- [x] TrackRepository（ローカル検索・getOrCreate・歌唱回数更新）
- [x] InsightRepository（タイムマシン・マイアンセムランキング取得）
- [x] ネットワーク監視ユーティリティ（NWPathMonitor）
- [x] タブナビゲーション基盤（TabView + 各タブ独立 NavigationStack）
- [x] DI 接続（@Environment + カスタム EnvironmentKey）
- [x] 歌唱記録シート（曲入力 → スコア → Intent → 歌唱日時 → メモ + 保存、1 枚のシートで完結）
- [x] 手動曲名入力（オフライン時の接続案内を含む）
- [x] 二重送信防止（UI 層: ボタン非活性化 + ProgressView / データ層: UUID 冪等性）
- [x] 歌唱記録フロー統合（曲選択 → 同一シートで入力完了 → 保存 → 履歴タブへ遷移）
- [x] History 画面（日時降順一覧、Intent フィルター、スコア/日時ソート、スワイプ削除、履歴からの編集）
- [x] Infinite Scroll（20 件ごとのページネーション、末尾 5 行でプリフェッチ、500 行上限）
- [x] Empty State（歌唱 0 件時の「まず 1 曲歌ってみよう！」+ 手動記録への導線）
- [x] インテントタブ UI（タイムマシンカード + マイアンセムカード + ランキングシート）
- [x] タイムマシン表示（過去 1 ヶ月の歌唱曲ランキング、ランキングからの歌唱記録シート連携）
- [x] 色・テーマ統一（AppColor セマンティック色トークン、AccentColor 統一）
- [x] マイアンセム表示部の UI 基盤（過去 3 ヶ月の Intent 別回数/点数ランキング）

---

## 🚧 未実装 / 今後の実装

### Phase 2 残り（V1 範囲外の一覧 `issues.md` ベース）

- [ ] I-020〜I-022: ハイブリッド検索画面（ローカル + Spotify API 検索、Debounce 0.5 秒、手動追加導線）

> **マイアンセム（Issue 番号の整理）**: 全体版 `docs/issues.md` の **I-019（マイアンセム表示）** に相当する UI は、**V1 では `docs/v1_issues.md` の [I-017]** に統合して実装済み（`MyAnthemRankingSheetView` 等）。README の Phase 2 表の I-017 を参照。

### Phase 3: Spotify 連携

- [ ] I-023: OAuth 2.0 PKCE 認証実装
- [ ] I-024: トークンリフレッシュ
- [ ] I-024A: TrackMetadataService / TrackMetadataCache（actor ベースの 24h インメモリキャッシュ）
- [ ] I-025: 最近再生した曲 API
- [ ] I-026: Spotify 視聴履歴タブ
- [ ] I-027: Spotify 検索 API（Debounce 0.5 秒）
- [ ] I-028: オフライン時のフォールバック（TrackMetadataCache）
- [ ] I-029: 指数バックオフ・リトライ
- [ ] I-030: API エラー時の再試行 UI
- [ ] I-031: オンボーディング画面

### Phase 4: 機能拡張・品質

- [ ] I-032: 手動リフレッシュ
- [ ] I-033: 設定画面（Spotify クレジット、プライバシーポリシーリンク）
- [ ] I-034: JSON 構造化ログ
- [ ] I-035: PII マスキング（SHA-256）
- [ ] I-036〜I-037: アクセシビリティ（VoiceOver / Dynamic Type）
- [ ] I-038: Repository 単体テスト拡充
- [ ] I-039: UI テスト（E2E）

---

## ⚠️ 仕様との差分

実装コード・仕様書（raw_spec.md v4.1 / spec.md / basic_design.md / detailed_design.md）・`.cursorrules` を三者照合した結果、以下の差分を確認した。

| 項目 | 仕様上の定義 | 実装状況 | 備考 |
|------|-------------|----------|------|
| Spotify OAuth 認証（FR-009 / I-023） | Must — spec.md FR-009, basic_design §6.1 | ❌ 未実装 | Phase 3 で対応予定 |
| TrackMetadataCache（24h TTL） | detailed_design §3.3, constitution §I | ❌ 未実装 | Phase 3 I-024A で対応予定。設計は完了 |
| Spotify 検索 API（Debounce 0.5s） | raw_spec §2.2, spec.md FR-005 | ❌ 未実装 | Phase 2 I-020〜I-022 → Phase 3 I-027 |
| ハイブリッド検索画面 | basic_design §1.2 UC-004 | ❌ 未実装 | Phase 2 残り |
| Spotify クレジット「Powered by Spotify」 | spec.md FR-018, constitution §I | ❌ 未実装 | Phase 4 I-033 で設定画面に配置予定 |
| プライバシーポリシーリンク | spec.md FR-019 | ❌ 未実装 | Phase 4 I-033 で設定画面に配置予定 |
| `fetchByIntent` の実装方式 | detailed_design: DB 側 Predicate による絞り込み | ⚠️ 差分あり | SwiftData の `#Predicate` が Intent enum で安定しないため、直近ウィンドウの `fetchAll` + メモリ filter で代替（コード内コメントに理由記載） |
| 指数バックオフ（初回 1s / 倍率 2 / Jitter ±25%） | detailed_design §5.5 | ❌ 未実装 | Phase 3 I-029 で対応予定 |
| JSON 構造化ログ | raw_spec §7.3 | ❌ 未実装 | Phase 4 I-034 で対応予定 |

> **注**: 上記はすべて Phase 3/4 のスコープであり、V1（Phase 0〜2）では意図的に対象外としたもの。V1 範囲内での仕様と実装の乖離はない。

---

## 💡 工夫した点

### 1. Spotify API 規約と設計の両立

Spotify API 規約でメタデータの永続保存が禁止されている制約に対し、**Track エンティティに `spotifyTrackId` のみを保持し、表示用メタデータを V2 で actor ベースのインメモリ TTL キャッシュから取得する設計**を採用。V1 では `userEnteredName`（ユーザー生成データ）で曲名表示を行い、規約準拠と UX を両立させた。

### 2. 冪等性の二重保証

**UI 層**（ボタン即時非活性化 + ProgressView + インタラクションブロック）と**データ層**（UUID による `exists` チェック → 既存なら skip）の 2 段階で二重送信を防止。ネットワーク遅延や再試行による重複登録を完全に排除した。

### 3. 歌唱記録の 1 シート統合

仕様上は Intent 選択画面・歌唱記録入力画面が別画面（S-004/S-005）だったが、**UX 改善のため 1 枚の Recording Sheet に統合**し、**曲名入力 → スコア → Intent → 歌唱日時 → メモ → 保存**を途切れなく完結できるようにした。`NavigationStack` の push ではなく `.sheet(item:)` を採用し、保存後の「ルート画面チラつき」を回避した。

### 4. History の値型スナップショットパターン

`HistoryViewModel` は SwiftData インスタンスを直接保持せず、`HistorySessionRowDisplayItem`（値型）にマッピングして保持。これにより:
- 削除時: 先にスナップショットから除外 → DB 削除失敗時はスナップショットを復元（楽観的 UI 更新）
- ソート・フィルター: 値型配列に対するメモリ上の操作で完結
- `loadGeneration` カウンタで非同期完了の交差を防止

### 5. SpecKit × Cursor による仕様駆動 + AI 支援開発

仕様書（raw_spec → spec.md → basic_design → detailed_design）→ クロスチェック → Issue 化 → 実装の一連のフローを SpecKit で標準化し、Cursor の `.cursorrules` で AI の出力品質を統制。仕様と実装の整合性を**レビューしやすい形で維持**した（自動テストでの完全検証は別タスク）。

---

## 🧠 苦労した点・学び

### 1. SwiftData の `#Predicate` の制約

SwiftData の `#Predicate` は enum 型（`Intent`）での絞り込みが安定しない場面があった。直近ウィンドウの `fetchAll` + メモリ上での filter に切り替え、`intentFilterCache` で同一 Intent のページ追加時の重複フェッチを抑制するアプローチを採用した。

### 2. NavigationStack と .sheet の共存

選曲タブで `NavigationStack` の push と `.sheet` が混在すると、シート dismiss 時に navigation が壊れるケースがあった。最終的に選曲タブは **NavigationStack（ルートのみ）+ `.sheet(item:)`** に統一し、保存後は `presentedRecordingRoute = nil`（シート解除）+ `selectedTab = .history` で遷移する方式に落ち着いた。

### 3. Spec と Code の三者照合の運用

仕様書群が 5 ファイル以上に及ぶため、raw_spec → spec.md → design docs → issues → code の一貫性維持に工夫が必要だった。`cross_check_report.md` による定期的な矛盾検出と、`v1_issues.md` を V1 の Single Source of Truth とする運用で対処した。

---

## ⚙️ 技術スタック

| カテゴリ | 技術 |
|----------|------|
| 言語 | Swift 5.9+ |
| UI フレームワーク | SwiftUI |
| ローカル DB | SwiftData（iOS 17+） |
| 状態管理 | `@Observable`（Observation framework） |
| 非同期処理 | Swift Concurrency（async/await） |
| ネットワーク | URLSession（V2: Spotify Web API） |
| 認証 | OAuth 2.0 PKCE（V2: Keychain 保存） |
| キャッシュ | actor ベースインメモリ TTL キャッシュ（V2） |
| ネットワーク監視 | NWPathMonitor（Network framework） |
| テスト | XCTest |
| 最低対応 OS | iOS 17.0 |
| 対応言語 | 日本語のみ |
| 対象デバイス | iPhone のみ |

---

## 🛠 セットアップ方法

### 前提条件

- Xcode 15.0 以上
- iOS 17.0 以上のシミュレータまたは実機
- macOS Sonoma 以上

### 手順

```bash
# 1. リポジトリをクローン（URL は自身のフォークに置き換え）
git clone https://github.com/omomi-moti/Karaoke_support.git
cd Karaoke_support

# 2. Xcode でプロジェクトを開く
open Karaoke_support/Karaoke_support.xcodeproj

# 3. ビルドターゲットを確認
#    - Scheme: Karaoke_support
#    - Deployment Target: iOS 17.0

# 4. ビルド & 実行
#    - Cmd + R（シミュレータまたは実機）
```

> **注**: V1 は Spotify 連携未実装のため、Spotify Developer Dashboard の設定は不要。手動曲名入力で全機能を利用可能。

---

## ▶️ 実行方法

1. Xcode でプロジェクトを開く
2. iPhone シミュレータ（iOS 17+）を選択
3. `Cmd + R` でビルド & 実行
4. 選曲タブ → ツールバー「記録を追加」→ 手動曲名入力 → スコア → Intent 選択 → 保存

---

## 🧪 テスト

### ユニットテスト（14 ファイル）

```bash
# Xcode から実行
Cmd + U
```

| テストファイル | テスト対象 |
|---------------|-----------|
| `I011SessionIdempotencyTests` | データ層の冪等性（同一 UUID による二重登録防止） |
| `SwiftDataSessionRepositoryDeleteRecordingSessionTests` | 削除処理（singCount 減算・存在チェック） |
| `SwiftDataSessionRepositoryUpdateRecordingSessionTests` | 更新処理（Track 差し替え禁止・存在チェック） |
| `SwiftDataSessionRepositoryFetchByIntentTests` | Intent フィルター取得（ウィンドウ + メモリ filter） |
| `SwiftDataSessionRepositoryFetchRecordingSessionTests` | 単一セッション取得 |
| `HistoryViewModelPaginationTests` | ページネーション（20 件単位・プリフェッチ） |
| `HistoryViewModelSortTests` | ソート（日時順・スコア順） |
| `HistorySortOrderTests` | ソート順の定義と比較 |
| `IntentTabViewModelTests` | インサイト取得（成功・0 件・エラー・並行制御・月次統計） |
| `InsightTrackRowTitleTests` | ランキング行の曲名表示（優先順位・フォールバック） |
| `RecordingSheetViewModelEditSaveTests` | 編集モード保存（新規 vs 既存の分岐） |
| `SingingEmptyStateCopyTests` | Empty State の文言 |
| `TrackDisplayTitleTests` | 曲名表示ヘルパー（userEnteredName 優先） |
| `Karaoke_supportTests` | Xcode テンプレート由来のプレースホルダー（本番の検証は他ファイルに集約） |

### UI テスト

```bash
# UIテスト実行
Cmd + U（Scheme: Karaoke_supportUITests）
```

| テストファイル | テスト対象 |
|---------------|-----------|
| `Karaoke_supportUITestsLaunchTests` | アプリ起動テスト（in-memory ModelContainer） |

### 手動 QA

- `docs/manual_qa_I008_I009_record_save.md`: 歌唱記録保存フローの手動テスト手順

---

## 📌 今後の改善

1. **Spotify 連携の実装（Phase 3）**: OAuth 認証 → メタデータキャッシュ → 検索 API → 視聴履歴
2. **アクセシビリティ強化（Phase 4）**: VoiceOver / Dynamic Type 対応
3. **JSON 構造化ログ（Phase 4）**: Latency / Error Rate の運用監視
4. **パフォーマンス最適化**: `fetchByIntent` の DB 側 Predicate 対応（SwiftData の安定後）、月次統計の打ち切り最適化
5. **データエクスポート**: JSON / CSV エクスポート機能
6. **iCloud 同期**: 将来的な複数デバイス対応

---

## 👤 Author

- **GitHub**: [@omomi-moti](https://github.com/omomi-moti)
