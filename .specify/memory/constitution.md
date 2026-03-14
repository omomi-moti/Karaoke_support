# ヒトカラモバイルiOS Constitution

> **Status: ACTIVE CONSTITUTION**  
> このファイルはヒトカラモバイルiOS プロジェクトの開発原則と品質基準を定義します。  
> `/speckit.plan` や `/speckit.analyze` はこの憲法を参照して、仕様やプランを自動チェックします。

---

## Core Principles

### I. Spotify API 規約準拠

すべての設計・実装は Spotify API 利用規約を遵守しなければならない。特に：
- メタデータ（曲名・アーティスト名・アートワーク等）の永続保存は禁止
- メタデータのキャッシュはインメモリのみ許可し、永続化してはならない（最長24時間以内のTTLを許容し、アプリ再起動時には初期化する）
- 取得したデータは表示目的のみに使用
- 検索画面・設定画面に「Powered by Spotify」クレジット配置

### II. オフラインファースト設計

ネットワーク未接続状態でも、基本機能（歌唱記録・履歴閲覧）は動作しなければならない。
- SwiftData がローカルDB の唯一の真実の源（SSOT）
- ユーザーの Intent・メモ等の機微情報は端末内のみ保存、外部送信しない
- ネットワーク復帰時は外部同期を行わず、`spotifyTrackId` を用いたメタデータ再取得で表示を補完する

### III. Track と SingingSession の明確な分離

データモデルは以下の責務を厳密に分ける：
- **Track（楽曲）**: spotifyTrackId（識別子）、userEnteredName（手動入力）、singCount（集計）、createdAt/updatedAt
- **SingingSession（歌唱記録）**: Intent、スコア（0〜100）、メモ、日時を毎回新規作成
- 重複排除の対象は **Track 側のメタデータ・ID** のみ（SingingSession は都度追加）

### IV. ドキュメント間の一貫性

仕様書（spec.md）・基本設計（basic_design.md）・詳細設計（detailed_design.md）は矛盾しない。
- 技術選定（例：インメモリキャッシュ）は全文書で統一
- データモデル定義（Track・SingingSession）は一貫
- API 規約への制約は明示的に記載

### V. テスト可能性と検証

すべての重要な動作は自動・手動で検証可能でなければならない。
- UI層：ユーザー操作の応答確認
- DB層：SwiftData の永続化と重複排除ルール確認
- API層：Spotify API の呼び出しとキャッシュ戦略の確認
- 特に「同一曲の複数回記録」は重複排除が正しく機能することを確認

---

## Architecture Rules

### 依存性注入（DI）

- **方針**: DIライブラリは使用しない。手動コンストラクタインジェクションを標準とする
- **ルート**: `@main` の App 起点で依存を組み立て、`@EnvironmentObject` または初期化引数で ViewModel に渡す
- **禁止**: ViewModel が Repository の具体実装クラスを直接 `init` すること
- **許容**: Protocol (interface) に依存することで、テスト時にモック実装に差し替え可能とする

### ディレクトリ構成

レイヤー別（Presentation / Domain / Data）構成を標準とする：

```
Sources/
├── Presentation/        # View + ViewModel（画面単位でサブフォルダ）
│   ├── Recording/
│   ├── Search/
│   ├── Insight/
│   └── History/
├── Domain/              # Protocol定義・モデル（フレームワーク非依存）
│   ├── Models/          # Track, SingingSession, Intent
│   └── Repositories/    # SessionRepository(protocol), TrackRepository(protocol)
└── Data/                # 具体実装（SwiftData, Spotify, Cache）
    ├── SwiftData/
    ├── Spotify/
    └── Cache/
```

- Presentation → Domain Protocol に依存。Data の具体実装には依存しない
- Domain は原則として外部フレームワーク（SwiftData 等）に依存しない純粋な Swift とする。**例外**: 永続化に SwiftData を用いる場合に限り、Track および SingingSession の @Model 定義を Domain/Models に置くことを許容する（型の二重定義とマッピング層を避け、実装をシンプルに保つため）。
- 新機能追加時は必ず上記レイヤーに従って配置する

---

## Spotify API 規約準拠と規制

- **メタデータの永続保存禁止**
  - メタデータはインメモリキャッシュとしてのみ実装し、DB・UserDefaults・ディスクへ永続化しない
  - 許容されるのは「最長24時間以内のインメモリTTLキャッシュ」のみとし、アプリ再起動時には初期化する
  
- **クレジット表記**
  - 検索画面・設定画面に「Powered by Spotify」ロゴ配置
  
- **認証方式**
  - OAuth 2.0 PKCE フロー必須実装
  - トークンは Keychain に安全に保存

- **プライバシー**
  - アプリ内に「すべてのデータは端末内保存」旨を明記

---

## 開発ワークフロー

- **Spec確認**: spec.md が raw_spec.md v4.1 と矛盾していないか確認
- **設計レビュー**: 
  - Track・SingingSession のデータモデルが正確か
  - Spotify 規約違反の懸念がないか
  - インメモリキャッシュ戦略が明示されているか
  
- **実装検証**:
  - テストプラン含む
  - 重複排除ロジックの動作確認
  - オフライン時の振舞い確認

- **マージ基準**:
  - spec.md・basic_design.md・detailed_design.md が一貫性を持つ
  - Spotify 規約準拠の懸念がない
  - 矛盾・プレースホルダが解決されている

---

## Governance

- この憲法は、spec.md・basic_design.md・detailed_design.md より **優先される**
- 修正時は PR で以下を記載：
  - 修正理由
  - 影響を受けるドキュメント
  - 必要な移行・採用作業
  
- speckit.plan / speckit.analyze は、この憲法に対する準拠性を基準に自動チェック  
  → 準拠できない項目は「評価不可」として報告

**Version**: 1.1.1 | **Ratified**: 2026-03-13 | **Last Amended**: 2026-03-13
