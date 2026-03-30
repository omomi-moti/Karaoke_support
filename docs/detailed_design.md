# ヒトカラモバイルiOS - 詳細設計書

**Version**: 1.1  
**Created**: 2026-03-12  
**Updated**: 2026-03-12（Spotify API規約準拠、メタデータ非永続化）  
**参照**: docs/basic_design.md, specs/001-hitora-karaoke-ios/spec.md

---

## 1. 処理フロー（シーケンス図）

### 1.1 歌唱セッション保存フロー（オンライン）

```mermaid
sequenceDiagram
    participant User
    participant View
    participant ViewModel
    participant Repository
    participant SwiftData
    participant SpotifyAPI

    User->>View: 保存ボタンタップ
    View->>View: ボタン非活性化、ProgressView表示
    View->>ViewModel: saveSession(intent, score, memo)
    ViewModel->>ViewModel: UUID生成（Idempotency Key）
    ViewModel->>Repository: saveSession(session)
    Repository->>SwiftData: exists(uuid)?
    alt 既存あり
        SwiftData-->>Repository: true
        Repository-->>ViewModel: スキップ（二重防止）
    else 新規
        SwiftData-->>Repository: false
        Repository->>SwiftData: insert(session)
        SwiftData-->>Repository: OK
        opt ネットワーク接続中 & Track ID 未取得
            Repository->>SpotifyAPI: search(q=曲名)
            SpotifyAPI-->>Repository: track id
            Repository->>SwiftData: update(trackId)
        end
        Repository-->>ViewModel: success
    end
    ViewModel-->>View: 完了
    View->>View: ボタン復帰、ProgressView非表示
    View-->>User: 履歴へ遷移 or 完了表示
```

### 1.2 歌唱セッション保存フロー（オフライン）

```mermaid
sequenceDiagram
    participant User
    participant View
    participant ViewModel
    participant Repository
    participant SwiftData

    User->>View: 保存ボタンタップ
    View->>ViewModel: saveSession(intent, score, memo)
    ViewModel->>Repository: saveSession(session)
    Repository->>SwiftData: insert(Track(userEnteredName: ...) 等のユーザー生成データのみ)
    Repository->>SwiftData: insert(session, trackId=track.id)
    Note over Repository,SwiftData: trackId FK は必須。オフライン時は Track(userEnteredName:) で手動入力曲を生成して紐付ける。Spotify 由来メタデータは最長24時間のインメモリTTLキャッシュでのみ保持し、SwiftData へ永続化しない
    SwiftData-->>Repository: OK
    Repository-->>ViewModel: success
    ViewModel-->>View: 完了
    View-->>User: エラーを出さずに保存完了
```

### 1.3 ハイブリッド検索フロー

```mermaid
sequenceDiagram
    participant User
    participant SearchView
    participant SearchViewModel
    participant LocalRepo
    participant SpotifyRepo
    participant SwiftData
    participant SpotifyAPI

    User->>SearchView: キーワード入力 "abc"
    SearchView->>SearchViewModel: search(query="abc")
    SearchViewModel->>LocalRepo: searchLocal("abc")
    LocalRepo->>SwiftData: fetch(predicate, sort: 歌った回数降順)
    SwiftData-->>LocalRepo: [Track]
    LocalRepo-->>SearchViewModel: localResults
    SearchViewModel-->>SearchView: 即座にローカル結果表示

    Note over User,SpotifyAPI: 0.5秒 Debounce

    User->>SearchView: 入力停止
    SearchView->>SearchViewModel: debouncedSearch("abc")
    alt ネットワーク接続中
        SearchViewModel->>SpotifyRepo: search("abc")
        SpotifyRepo->>SpotifyAPI: GET /v1/search?q=abc&type=track
        SpotifyAPI-->>SpotifyRepo: tracks
        SpotifyRepo-->>SearchViewModel: spotifyResults
        SearchViewModel-->>SearchView: ローカル結果 + Spotify結果（下部に追加）
    else オフライン
        SearchViewModel-->>SearchView: ローカル結果のみ + 「手動で追加して歌う」
    end
```

### 1.4 インサイト取得フロー（起動時）

```mermaid
sequenceDiagram
    participant App
    participant InsightViewModel
    participant Repository
    participant SwiftData

    App->>InsightViewModel: 画面表示
    InsightViewModel->>Repository: fetchTimeMachineRanking()
    Repository->>SwiftData: fetch(過去1ヶ月, group by track, count)
    SwiftData-->>Repository: [(track, count)]
    Repository-->>InsightViewModel: タイムマシン

    InsightViewModel->>Repository: fetchMyAnthemRankings(period: threeMonths)
    Repository->>SwiftData: fetch(過去3ヶ月, group by intent, track, count/score)
    SwiftData-->>Repository: [(intent, track, count, avgScore)]
    Repository-->>InsightViewModel: マイアンセム

    InsightViewModel-->>App: インサイト表示（API待ちなし）
```

---

## 2. クラス図

```mermaid
classDiagram
    direction TB

    class SingingSession {
        +UUID id
        +Intent intent
        +Date performedAt
        +Double score
        +String? memo
    }

    class Track {
        +UUID id
        +String? spotifyTrackId
        +String? userEnteredName
        +Int singCount
        +Double? latestScore
    }

    class TrackMetadata {
        <<struct>>
        +String spotifyTrackId
        +String name
        +String artistName
        +URL? artworkURL
    }

    class Intent {
        <<enumeration>>
        shout
        emo
        practice
    }

    class SessionRepository {
        <<interface>>
        +save(SingingSession) async throws
        +fetchAll(limit, offset) async throws: [SingingSession]
        +fetchByIntent(Intent) async throws: [SingingSession]
        +exists(uuid) async throws: Bool
    }

    class TrackRepository {
        <<interface>>
        +searchLocal(query) async throws: [Track]
        +getOrCreate(spotifyTrackId?, userEnteredName?) async throws: Track
        +incrementSingCount(trackId) async throws
    }

    class TrackMetadataService {
        +fetchMetadata(trackId) async throws: TrackMetadata
    }

    class TrackMetadataCache {
        <<actor>>
        +get(trackId) async throws: TrackMetadata?
        +set(metadata) async throws
    }

    class InsightRepository {
        <<interface>>
        +fetchTimeMachineRanking() async throws
        +fetchMyAnthemRankings(period: InsightPeriod) async throws
    }

    class SessionListViewModel {
        <<MainActor>>
        -SessionRepository repo
        +sessions: [SingingSession]
        +selectedIntent: Intent?
        +loadSessions()
        +filterByIntent(Intent)
    }

    class RecordingViewModel {
        <<MainActor>>
        -SessionRepository repo
        -TrackRepository trackRepo
        +save(intent, score, memo)
        +isSaving: Bool
    }

    class SearchViewModel {
        <<MainActor>>
        -TrackRepository trackRepo
        -SpotifySearchService spotify
        +localResults: [Track]
        +spotifyResults: [SpotifyTrack]
        +search(query)
        +debouncedSearch(query)
    }

    class InsightViewModel {
        <<MainActor>>
        -InsightRepository repo
        -TrackMetadataService metadataService
        +timeMachine: [(Track, Int)]
        +myAnthem: [(Intent, Track, Int, Double)]
        +loadInsights()
    }

    TrackMetadataService --> TrackMetadataCache : uses
    TrackMetadataService --> SpotifyAPIClient : uses
    InsightViewModel --> TrackMetadataService : uses
    SingingSession --> Track : references
    SingingSession --> Intent : uses
    SessionRepository ..> SingingSession : manages
    TrackRepository ..> Track : manages
    InsightRepository ..> Track : reads
    SessionListViewModel --> SessionRepository : uses
    RecordingViewModel --> SessionRepository : uses
    RecordingViewModel --> TrackRepository : uses
    SearchViewModel --> TrackRepository : uses
    InsightViewModel --> InsightRepository : uses
```

- `SessionRepository.fetchAll(limit, offset)` は `performedAt` 降順で返す。
- `TrackRepository.searchLocal(query)` は `singCount` 降順で返す。

---

## 3. データベース設計

### 3.1 SwiftData スキーマ設計（Spotify API規約準拠）

```mermaid
erDiagram
    Track ||--o{ SingingSession : "has many"
    Track {
        uuid id PK
        string spotifyTrackId "nullable"
        string userEnteredName "nullable, 手動入力時のみ"
        int singCount "集計"
        double latestScore "nullable, 集計"
        datetime createdAt
        datetime updatedAt
    }

    SingingSession {
        uuid id PK
        uuid trackId FK
        string intent "shout|emo|practice"
        datetime performedAt
        double score "0-100"
        string memo "nullable"
    }

    Track ||--o{ SingingSession : "1曲に複数セッション"
```

**Spotify API規約準拠**: Spotify から取得した曲名・アーティスト名・アートワーク等は永続化しない。永続化するのは Track ID、ユーザーが手動入力した曲名（`userEnteredName`）、ユーザー入力データ（スコア、Intent、メモ等）、集計情報のみ。`userEnteredName` はオフライン時の手動入力曲用（ユーザー生成データのため永続化可）。

**補足**: 同一曲の2回目以降は既存 Track を取得し、新規 SingingSession のみ追加する。

### 3.2 エンティティ定義（SwiftData @Model）

```swift
// Why: Spotify API規約により、曲名・アーティスト名・アートワーク等の永続保存が禁止されているため。
// 永続化するのは Track ID と集計情報のみ。表示用メタデータは API または一時キャッシュから取得する。
@Model
final class Track {
    @Attribute(.unique) var id: UUID
    var spotifyTrackId: String?
    /// 手動入力曲用。ユーザーが入力した曲名（ユーザー生成データのため永続化可）。Spotify メタデータではない。
    var userEnteredName: String?
    var singCount: Int
    var latestScore: Double?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SingingSession.track)
    var sessions: [SingingSession] = []
}

enum Intent: String, Codable {
    case shout
    case emo
    case practice
}

@Model
final class SingingSession {
    @Attribute(.unique) var id: UUID  // Idempotency Key
    var track: Track
    /// ドメインでは enum を使用し、永続化時は RawValue(String) で扱う。
    var intent: Intent
    var performedAt: Date
    var score: Double
    var memo: String?
}
```

**補足（Track の生成）**: Track は「どちらか必須」を型で保証するため、public の初期化子を 2 本用意している。`init(spotifyTrackId: String, userEnteredName: String? = nil, ...)`（Spotify 由来の曲用）と `init(userEnteredName: String, spotifyTrackId: String? = nil, ...)`（手動入力曲用）。`Track()` や両方 nil での生成はコンパイル不可。空文字は precondition で拒否。代入ロジックは private init に集約している。

**補足（紐付けの正本）**: Track と外部データの紐付けは `Track.spotifyTrackId` を唯一の正本キーとして扱う。`SingingSession` は `Track` への外部キー（`track` リレーション）のみを持ち、`spotifyTrackId` を冗長に保持しない。曲名・アーティスト名・アートワーク等は表示用の揮発データであり、SwiftData には保存しない。

### 3.3 メタデータの一時キャッシュ（Spotify視聴履歴・表示用）

```swift
// Why: Spotify API規約によりメタデータの永続保存が禁止。24時間以内の一時キャッシュのみ許容。
// actor ベースのインメモリキャッシュでスレッドセーフを保証。永続化しないため規約準拠。
struct CachedMetadata {
    let metadata: TrackMetadata
    let expiresAt: Date
}

actor TrackMetadataCache {
    private var cache: [String: CachedMetadata] = [:]
    private let maxAge: TimeInterval = 24 * 60 * 60  // 24時間
    private let maxCount: Int = 500  // 上限超過時は期限切れ優先で削除し、残りは古い順に削除

    func get(_ trackId: String, now: Date = Date()) -> TrackMetadata? {
        guard let entry = cache[trackId], entry.expiresAt > now else {
            cache.removeValue(forKey: trackId)
            return nil
        }
        return entry.metadata
    }

    func set(_ metadata: TrackMetadata, now: Date = Date()) {
        cache[metadata.spotifyTrackId] = CachedMetadata(
            metadata: metadata,
            expiresAt: now.addingTimeInterval(maxAge)
        )
        if cache.count > maxCount {
            evictIfNeeded(now: now)
        }
    }

    // maxCount を超えた場合は:
    // 1. 期限切れエントリをすべて削除
    // 2. それでも maxCount を超える場合は expiresAt が古い順に削除
    private func evictIfNeeded(now: Date) {
        cache = cache.filter { $0.value.expiresAt > now }
        guard cache.count > maxCount else { return }
        let overflow = cache.count - maxCount
        let sortedByExpiry = cache.sorted { $0.value.expiresAt < $1.value.expiresAt }
        for (index, element) in sortedByExpiry.enumerated() where index < overflow {
            cache.removeValue(forKey: element.key)
        }
    }
}
```

### 3.4 最近再生した曲のキャッシュ

```swift
// Why: 最近再生した曲は流動的で件数も限定的。SwiftDataより軽量。
// インメモリキャッシュのみ。最長24時間のTTLを持ち、アプリ再起動で消える。永続化しない。
struct RecentlyPlayedCache {
    // 保存形式: メモリ上のキャッシュ（Track オブジェクト配列）
    // 有効期限: 最長24時間またはアプリ再起動まで。再起動で初期化。
}
```

### 3.5 メタデータ欠損時の表示状態

```swift
enum TrackMetadataState {
    case available(TrackMetadata)
    case unavailableOffline
    case unavailableExpired
    case unavailableApiError
}
```

- `spotifyTrackId` が存在しメタデータが欠損していても、レコードは有効データとして表示する。
- 欠損時はプレースホルダ文言（例:「曲情報を取得できません」）と再試行導線を表示する。
- スコア・Intent・日時・メモは常に表示し、ユーザーの記録閲覧体験を維持する。

### 3.6 App Store審査・コンプライアンス

- **Spotify クレジット**: 検索結果画面・設定画面に「Powered by Spotify」ロゴ等を配置。
- **プライバシーポリシー**: アプリ内に「データは端末内のみ保存、外部送信なし」旨のプライバシーポリシー（Web）へのリンクを設置。

---

## 4. ディレクトリ構成

実装の最新ツリーは **README の「📂 ディレクトリ構成」** と一致させる。概要は次のとおり。

```
Sources/
├── App/                          # @main、EnvironmentKey（DI）、プレビュー用モック
│   ├── KaraokeSupportApp.swift
│   ├── Environment/              # Repository / Network / ナビ用 EnvironmentKey
│   └── PreviewSupport/           # プレビュー用モック Repository
├── Presentation/                 # View + ViewModel（画面単位でサブフォルダ）
│   ├── Recording/                # 歌唱記録シート（Sheet / Sections / TrackInput 等）
│   ├── History/                  # 履歴一覧（List / Filters 等）
│   ├── Songs/                    # 選曲ルート・インテントタブ（IntentTab / TimeMachine / MyAnthem / Ranking 等）
│   ├── Insight/                  # プレースホルダー（将来）
│   ├── Search/                   # V2 プレースホルダー
│   ├── Settings/                 # プレースホルダー
│   ├── Root/                     # RootView（TabView）
│   ├── Common/                   # 共通コンポーネント
│   └── Theme/                    # AppColor 等
├── Domain/                       # Protocol・モデル（フレームワーク非依存が原則）
│   ├── Models/                   # SwiftData / Enums / Flow / Rankings 等
│   ├── Repositories/             # *RepositoryProtocol、エラー型等
│   └── Helpers/                  # TrackDisplayTitle 等
└── Data/                         # 具体実装
    ├── SwiftData/                # SwiftData*Repository
    ├── Network/                  # NetworkMonitor
    ├── Spotify/                  # V2 用
    └── Cache/                    # V2 用
```

**ユニットテスト**: `Karaoke_supportTests/` は上記レイヤに対応するよう `Domain` / `Data` / `Presentation` にミラー配置する（詳細は README）。

**依存の方向**: `Presentation → Domain Protocol ← Data`
- Presentation は Domain の Protocol に依存する。Data の具体実装には依存しない
- Domain は SwiftData 等の外部フレームワークに依存しない
- DI は App 起点で手動コンストラクタインジェクションで行う（DIライブラリ不使用）

---

## 5. API仕様書（Spotify Web API）

### 5.1 利用エンドポイント一覧

| 用途 | エンドポイント | メソッド | スコープ |
|------|---------------|----------|----------|
| 最近再生した曲 | `/v1/me/player/recently-played` | GET | user-read-recently-played |
| 曲検索 | `/v1/search` | GET | （標準スコープ） |

### 5.2 最近再生した曲

**Request**

```
GET https://api.spotify.com/v1/me/player/recently-played?limit=50
Authorization: Bearer {access_token}
```

| パラメータ | 型 | 必須 | 説明 |
|------------|-----|------|------|
| limit | int | 任意 | 1-50、デフォルト20 |
| after | int | 任意 | Unix ms、この時刻以降 |
| before | int | 任意 | Unix ms、この時刻以前（afterと排他） |

**Response（200）**

```json
{
  "href": "https://api.spotify.com/v1/me/player/recently-played",
  "limit": 50,
  "next": "string | null",
  "cursors": { "after": "string", "before": "string" },
  "total": 0,
  "items": [
    {
      "track": {
        "id": "string",
        "name": "string",
        "artists": [{ "id": "string", "name": "string" }],
        "album": { "id": "string", "name": "string", "images": [...] }
      },
      "played_at": "2024-01-01T00:00:00.000Z"
    }
  ]
}
```

### 5.3 曲検索

**Request**

```
GET https://api.spotify.com/v1/search?q={query}&type=track&limit=20&market=JP
Authorization: Bearer {access_token}
```

| パラメータ | 型 | 必須 | 説明 |
|------------|-----|------|------|
| q | string | 必須 | 検索クエリ |
| type | string | 必須 | "track" |
| limit | int | 任意 | 1-50、デフォルト20 |
| market | string | 任意 | ISO 3166-1 alpha-2（例: JP） |

**Response（200）**

```json
{
  "tracks": {
    "href": "string",
    "limit": 20,
    "next": "string | null",
    "offset": 0,
    "total": 0,
    "items": [
      {
        "id": "string",
        "name": "string",
        "artists": [{ "id": "string", "name": "string" }],
        "album": { "id": "string", "name": "string", "images": [...] }
      }
    ]
  }
}
```

### 5.4 オフライン・エラー時のフォールバック処理

```mermaid
flowchart TD
    A[API呼び出し] --> B{ネットワーク接続?}
    B -->|No| C[ローカルキャッシュ/DBのみ使用]
    B -->|Yes| D[リクエスト送信]
    D --> E{レスポンス}
    E -->|200| F[正常処理]
    E -->|401| G[トークンリフレッシュ試行]
    G --> H{成功?}
    H -->|Yes| D
    H -->|No| I[再ログイン案内UI]
    E -->|429| J[指数バックオフ + Jitter]
    J --> K[リトライ]
    K --> D
    E -->|4xx/5xx| L[エラーログ + 再試行UI表示]
    L --> C
```

| 状況 | フォールバック |
|------|----------------|
| ネットワーク未接続 | ローカルDB/インメモリTTLキャッシュのみ表示。手動曲名入力時は「ネットワークに接続してください」＋導線。 |
| 401 Unauthorized | リフレッシュトークンで再取得。失敗時は再ログイン案内。 |
| 429 Too Many Requests | 指数バックオフ（例: 1s, 2s, 4s...）+ Jitterでリトライ。ユーザーには「しばらく待ってから再試行」表示。 |
| タイムアウト | 30秒でタイムアウト。ローカルデータで継続、再試行UI表示。 |
| その他 4xx/5xx | エラーログ出力。再試行ボタン表示。該当機能は一時無効化可能。 |

### 5.5 指数バックオフ仕様

- **初回待機**: 1秒
- **倍率**: 2（1s → 2s → 4s → 8s...）
- **最大待機**: 60秒
- **Jitter**: ±25% のランダム加算（Thundering herd回避）
- **最大リトライ**: 5回
