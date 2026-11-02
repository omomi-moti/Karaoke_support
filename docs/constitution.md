# ヒトカラモバイルiOS Constitution

> **Status: ACTIVE CONSTITUTION**  
> このファイルはヒトカラモバイルiOS プロジェクトの開発原則と品質基準を定義します。

---

## Core Principles

### I. 外部の曲データの扱い

外部の曲データ（Spotify など）は、今は使っていない。使うときは、その API の利用規約で許された範囲だけを保存する：
- 曲名・アーティスト名・アートワーク等のメタデータは永続化しない（DB・UserDefaults・ディスクのいずれにも）。永続化してよいのは識別子（`spotifyTrackId` 等）だけ
- 認証・キャッシュ・クレジット表記などの具体的なやり方は、使うと決めたときに ADR で決める

### II. オフラインファースト設計

ネットワーク未接続状態でも、基本機能（歌唱記録・履歴閲覧）は動作しなければならない。
- 端末の SwiftData が唯一の真実の源（SSOT）。サーバーは本人が頼んだときだけ使う控え（バックアップ）で、サーバーが止まっていても基本機能は動く
- メモは端末内のみ保存し、外部送信しない
- 気分・点数・曲・日時などの記録は、本人がアカウントでバックアップを頼んだときだけ、自前のサーバーの本人のアカウントに送ってよい。第三者には渡さず、サーバーは記録の中身を読んだり集計したりしない
- 本人が頼まない限り、外部と同期しない
- アプリ内に、データをどこに保存するかを明記する。バックアップの機能をリリースのビルドに出すまでは「すべてのデータは端末内に保存する」のままでよい

### III. Track と SingingSession の明確な分離

データモデルは以下の責務を厳密に分ける：
- **Track（楽曲）**: userEnteredName（手動入力）、spotifyTrackId（外部の曲の識別子。今は使っていない）、singCount（集計）、createdAt/updatedAt
- **SingingSession（歌唱記録）**: Intent、スコア（0〜100）、メモ、日時を毎回新規作成
- 重複排除の対象は **Track 側のメタデータ・ID** のみ（SingingSession は都度追加）

### IV. ドキュメント間の一貫性

仕様とタスクは GitHub Issues、設計の判断は ADR（`docs/adr/`）を正とし、CLAUDE.md と docs はこれと矛盾させない。
- 技術選定は全文書で統一
- データモデル定義（Track・SingingSession）は一貫
- 外部 API を使うときは、その規約による制約を明示的に記載

### V. テスト可能性と検証

すべての重要な動作は自動・手動で検証可能でなければならない。
- UI層：ユーザー操作の応答確認
- DB層：SwiftData の永続化と重複排除ルール確認
- 外部 API を使うときは、その呼び出しとキャッシュの確認
- 特に「同一曲の複数回記録」は重複排除が正しく機能することを確認

---

## Architecture Rules

### 依存性注入（DI）

- **方針**: DIライブラリは使用しない。手動コンストラクタインジェクションを標準とする
- **ルート**: `@main` の App 起点で依存を組み立て（`AppDependencies`）、`@Environment`（EnvironmentKey または `.environment(_:)`）で View に渡し、View が ViewModel の初期化引数に渡す
- **禁止**: ViewModel が Repository の具体実装クラスを直接 `init` すること
- **許容**: Protocol (interface) に依存することで、テスト時にモック実装に差し替え可能とする

### ディレクトリ構成

レイヤー別（App / Presentation / Domain / Data）構成を標準とする：

```
Sources/
├── App/                 # @main、EnvironmentKey（DI）、プレビュー用モック
│   ├── KaraokeSupportApp.swift
│   ├── AppDependencies.swift  # 起動時に DB と Repository を組み立てる
│   ├── Environment/     # Repository 等の EnvironmentKey と、環境に置く値
│   └── PreviewSupport/  # プレビュー用モック Repository
├── Presentation/        # View + ViewModel（画面単位でサブフォルダ）
│   ├── Recording/       # Sheet / Sections / TrackInput 等（歌唱記録シート）
│   ├── AfterSave/       # 保存直後のシート（次の 1 曲の提案）
│   ├── History/         # List / Filters 等（履歴一覧）
│   ├── TrackDetail/     # 曲詳細
│   ├── Songs/           # 選曲タブ・インテントタブ等
│   ├── Search/          # 検索タブ
│   ├── Settings/        # 設定タブ
│   ├── Root/            # TabView・シートの切り替え・DB を開けなかったときの画面
│   ├── Common/
│   └── Theme/
├── Domain/              # Protocol定義・モデル（フレームワーク非依存）
│   ├── Models/          # Track, SingingSession, Intent, RecordSource 等
│   ├── Repositories/    # Session / Track / Insight / TrackStats の Repository(protocol)
│   └── Helpers/         # 次の 1 曲の計算、曲名の候補の並べ方 等
└── Data/                # 具体実装（SwiftData, Network）
    ├── SwiftData/       # Repository の実装
    ├── Network/         # NetworkMonitor
    ├── Spotify/         # 外部 API 用（まだ空）
    └── Cache/           # 外部 API 用（まだ空）
```

- Presentation → Domain Protocol に依存。Data の具体実装には依存しない
- **Data 層は SwiftUI に依存しない**。EnvironmentKey 等の SwiftUI DI 配線は App 層（`Sources/App/Environment/` 等）に配置する。
- Domain は原則として外部フレームワーク（SwiftData 等）に依存しない純粋な Swift とする。**例外**: 永続化に SwiftData を用いる場合に限り、Track および SingingSession の @Model 定義を Domain/Models に置くことを許容する（型の二重定義とマッピング層を避け、実装をシンプルに保つため）。
- 新機能追加時は必ず上記レイヤーに従って配置する

---

## 開発ワークフロー

- **仕様確認**: Issue の受け入れ条件と「決めたこと」が、ADR と矛盾していないか確認
- **設計レビュー**: 
  - Track・SingingSession のデータモデルが正確か
  - 外部の曲データのメタデータを永続化していないか
  
- **実装検証**:
  - テストプラン含む
  - 重複排除ロジックの動作確認
  - オフライン時の振舞い確認
  - モデルに項目を足したときは、前のビルドで作ったデータを新しいビルドで開いて確認

- **マージ基準**:
  - Issue の受け入れ条件を満たす
  - 判断を ADR に残している
  - プロジェクト用のレビュー（`karaoke-review`）を通している
  - 外部の曲データのメタデータを永続化していない
  - 矛盾・プレースホルダが解決されている

---

## Governance

- この憲法は、ADR・CLAUDE.md・docs より **優先される**
- 修正時は PR で以下を記載：
  - 修正理由
  - 影響を受けるドキュメント
  - 必要な移行・採用作業

**Version**: 1.4.0 | **Ratified**: 2026-03-13 | **Last Amended**: 2026-11-02（II を、端末を正としたまま、本人が頼んだときだけメモを除いた記録を自前のサーバーにバックアップできる形に変えた。ADR 0049）
