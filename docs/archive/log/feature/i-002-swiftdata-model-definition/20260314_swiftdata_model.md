# feature/i-002-swiftdata-model-definition 実装ログ

**日付**: 2026-03-14  
**対象**: [I-002] SwiftDataモデル定義

---

## ブランチの概要

SwiftData を用いたローカル永続化の基盤を整えるため、設計書（detailed_design.md §3.1〜3.2）に従い Track・SingingSession・Intent のエンティティを定義し、アプリエントリで ModelContainer を登録した。Spotify API 規約に準拠し、曲名・アーティスト名・アートワーク URL 等の Spotify 由来メタデータは永続化せず、参照キー（spotifyTrackId）とユーザー生成データ（userEnteredName）および集計・セッション情報のみを SwiftData に保持する構成としている。

---

## 主な実装・変更点

### 追加されたファイル

- **Sources/Domain/Models/Track.swift**
  - **定義内容**: `@Model` の `Track` クラス。プロパティは `id`（UUID, `@Attribute(.unique)`）、`spotifyTrackId`（String?）、`userEnteredName`（String?）、`singCount`（Int）、`latestScore`（Double?）、`createdAt` / `updatedAt`（Date）、および `sessions`（`[SingingSession]`、`@Relationship(deleteRule: .cascade, inverse: \SingingSession.track)`）。**初期化子**は、代入ロジックを集約した `private init(...)` と、公開用の 2 本（`init(spotifyTrackId: String, userEnteredName: String? = nil, ...)`：Spotify 用、`init(userEnteredName: String, spotifyTrackId: String? = nil, ...)`：手動入力用）を用意。どちらか一方を必須とするため `Track()` や両方 nil はコンパイル不可。空文字は precondition で拒否。
  - **設計意図**: **Spotify API 規約**により、曲名・アーティスト名・アートワーク等のメタデータの永続保存が禁止されているため、永続化するのは Spotify の参照キー（`spotifyTrackId`）と、オフライン時の手動入力用のユーザー生成曲名（`userEnteredName`）および集計情報（`singCount`, `latestScore`）と日時のみとした。表示用メタデータは API または一時キャッシュから取得する前提である。`@Attribute(.unique)` を `id` に付与した理由は、同一 Track の重複を防ぎ、Repository の getOrCreate 等で一意に識別するためである。**2 本の public init** にした理由は、無引数・両方 nil での生成をコンパイル時に防ぎ、運用時の誤りを減らすためである。`sessions` に `deleteRule: .cascade` を指定した理由は、Track 削除時に紐づく SingingSession をまとめて削除し、孤立レコードと参照整合性の崩れを防ぐためである。

- **Sources/Domain/Models/SingingSession.swift**
  - **定義内容**: `@Model` の `SingingSession` クラス。プロパティは `id`（UUID, `@Attribute(.unique)`、Idempotency Key）、`track`（Track）、`intent`（Intent）、`performedAt`（Date）、`score`（**Double**、0〜100、小数第二位まで。桁数・丸めは ViewModel で制御）、`memo`（String?）。明示的な `init` を定義し、`score` の範囲は Debug ビルドで `assert(score >= 0 && score <= 100)` を実施。Release では ViewModel のバリデーションに委ねる。
  - **設計意図**: 歌唱1回分を1セッションとして表現する。**紐付けの正本は Track.spotifyTrackId に一本化**する設計のため、SingingSession には `spotifyTrackId` を持たせず、`track` リレーションのみで Track を参照する。これにより、曲と外部データの対応は Track 側で一元管理でき、冗長と不整合を避けられる。`score` を Double にした理由は、スライダーや手入力で小数第二位まで扱うため。`id` を `.unique` にした理由は、保存時の冪等性キーとして重複保存を防ぐためである（SessionRepository.exists(uuid) と組み合わせる想定）。

- **Sources/Domain/Models/Intent.swift**
  - **定義内容**: `enum Intent: String, Codable`。case は `shout`, `emo`, `practice`。
  - **設計意図**: 歌唱の意図を型安全に扱うため enum とした。SwiftData は Codable 準拠の enum を RawValue（ここでは String）で永続化するため、追加の変換層は不要である。仕様・UI で用いる「Shout / Emo / Practice」をコード上で一意に識別し、将来的な case 追加やリネーム時の影響を局所化するためでもある。

### 変更されたファイル

- **Sources/App/KaraokeSupportApp.swift**
  - **変更内容**: `import SwiftData` を追加し、`WindowGroup` に `.modelContainer(for: [Track.self, SingingSession.self])` を付与した。
  - **変更理由**: SwiftData を利用するには、アプリ起動時にスキーマを登録した ModelContainer を Scene に渡す必要がある。ここで Track と SingingSession を登録することで、各 View や Repository が `@Environment(\.modelContext)` 等から同一のコンテキストを参照でき、永続化が動作する。

---

## 影響範囲

| 対象 | 内容 |
|------|------|
| **Domain 層** | `Sources/Domain/Models/` に Track・SingingSession・Intent が追加された。今後の SessionRepository / TrackRepository / InsightRepository はこれらの型を参照する。 |
| **アプリエントリ** | `KaraokeSupportApp` で ModelContainer が登録され、SwiftData スキーマが有効化された。View や ViewModel は modelContext を環境から取得して利用する想定。 |
| **永続化ポリシー** | Spotify 由来メタデータは SwiftData に保存しない。Track に持つのは spotifyTrackId・userEnteredName・集計・日時のみ。曲名・アーティスト・アートワーク等は API またはインメモリキャッシュから取得する。 |
| **リレーション** | Track 削除時は関連する SingingSession が cascade で削除される。SingingSession は Track への参照のみ持ち、spotifyTrackId は持たない。 |

---

## 追記（モデル仕様の変更）

- **Track の初期化子**: 運用で「両方 nil 禁止」を型で保証するため、単一 init + precondition から **2 本の public init**（`init(spotifyTrackId: String, ...)` / `init(userEnteredName: String, ...)`）に変更。代入ロジックは private init に集約。`Track()` や両方 nil はコンパイル不可。空文字は precondition で拒否。
- **SingingSession.score**: スライダー・手入力で小数を扱うため **Int → Double** に変更。0〜100 の範囲は Debug で `assert`、Release では ViewModel のバリデーションに委ねる。設計書（detailed_design.md）の score 型および I-002 ログ本文を上記に合わせて更新済み。

---

## 特記事項（憲法との整合）

- **Domain への @Model 配置**: 憲法（.specify/memory/constitution.md）では「Domain は原則として外部フレームワークに依存しない純粋な Swift」とされているが、永続化に SwiftData を用いる場合に限り、**Track および SingingSession の @Model を Domain/Models に置くことを許容する**旨の例外規定が追加されている。これにより、型の二重定義とマッピング層を設けず、実装をシンプルに保ったまま憲法と整合している。
