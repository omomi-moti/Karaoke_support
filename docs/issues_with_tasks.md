# ヒトカラモバイルiOS - Issue ラベル・タスク分解

**Version**: 1.0  
**Created**: 2026-03-12  
**参照**: docs/issues.md v1.1

---

## Phase 0: 基盤構築

### [I-001] プロジェクト初期化
- **Labels**: `priority:must`, `type:chore`, `phase:0-基盤`
- **Tasks**:
  - [x] Xcodeで新規iOSプロジェクトを作成する（iOS 17+、Swift 5.9）
  - [x] SwiftUIを選択し、不要なデフォルトファイル（ContentView等）を整理する
  - [x] フォルダ構成の雛形を作成する（Sources/Presentation/Domain/Data のレイヤー構成）
  - [x] Info.plist / プロジェクト設定で最低デプロイメントターゲットを iOS 17.0 に設定する

---

### [I-002] SwiftDataモデル定義
- **Labels**: `priority:must`, `type:feat`, `phase:0-基盤`
- **Tasks**:
  - [ ] Track エンティティを @Model で定義する（id, spotifyTrackId, userEnteredName, singCount, latestScore, createdAt, updatedAt）
  - [ ] SingingSession エンティティを @Model で定義する（id, track, intent, performedAt, score, memo）
        ※ spotifyTrackId は Track.spotifyTrackId に一本化。SingingSession 側には持たない。
  - [ ] Track と SingingSession のリレーション（1:N、cascade削除）を設定する
  - [ ] ModelContainer をアプリエントリポイントで初期化し、SwiftData スキーマを登録する

---

### [I-003] SessionRepository 実装
- **Labels**: `priority:must`, `type:feat`, `phase:0-基盤`
- **Tasks**:
  - [ ] SessionRepository プロトコル（インターフェース）を定義する
  - [ ] save(session) メソッドを実装する（SwiftData insert）
  - [ ] fetchAll(limit, offset) を実装する（日時降順）
  - [ ] fetchByIntent(intent) を実装する
  - [ ] exists(uuid) を実装する（冪等性チェック用）

---

### [I-004] TrackRepository 実装
- **Labels**: `priority:must`, `type:feat`, `phase:0-基盤`
- **Tasks**:
  - [ ] TrackRepository プロトコルを定義する
  - [ ] searchLocal(query) を実装する（userEnteredName に対する predicate、歌った回数降順）
  - [ ] getOrCreate(spotifyTrackId?, userEnteredName?) を実装する（既存検索 or 新規作成）
  - [ ] incrementSingCount(trackId) を実装する（集計更新）
  - [ ] 同一曲の2回目以降は既存 Track を返し、SingingSession のみ追加するロジックを確認する

---

### [I-005] InsightRepository 実装
- **Labels**: `priority:must`, `type:feat`, `phase:0-基盤`
- **Tasks**:
  - [ ] InsightRepository プロトコルを定義する
  - [ ] getTimeMachineRanking() を実装する（過去1ヶ月、歌唱回数降順）
  - [ ] getMyAnthemRanking() を実装する（Intent別の回数・点数ランキング）
  - [ ] SwiftData の @Query または FetchDescriptor で集計クエリを実装する

---

### [I-006] ネットワーク監視ユーティリティ
- **Labels**: `priority:must`, `type:feat`, `phase:0-基盤`
- **Tasks**:
  - [ ] NWPathMonitor を用いた NetworkMonitor クラス/構造体を作成する
  - [ ] 接続状態（online/offline）を @Published または AsyncStream で公開する
  - [ ] アプリ起動時に監視を開始し、状態変化を検知できるようにする
  - [ ] @Environment(\.networkMonitor) で参照できるよう EnvironmentKey を定義し、App 起点で注入する（I-012 等でオフライン判定に使用）

---

## Phase 1: MVP

### [I-007] タブナビゲーション基盤
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] TabView で選曲画面（2タブ）、History、設定の3タブを構成する
  - [ ] タブA: インテント、タブB: Spotify視聴履歴のセグメント/タブUIを配置する
  - [ ] History 画面への遷移をタブバーに追加する
  - [ ] 設定画面への遷移をタブバーに追加する

---

### [I-007A] 依存性注入（DI）接続
- **依存**: I-002, I-003, I-004, I-005, I-007
- **Labels**: `priority:must`, `type:chore`, `phase:1-MVP`
- **Tasks**:
  - [ ] App エントリで ModelContainer を参照（I-002 で登録済みの場合は確認のみ）
  - [ ] SessionRepository / TrackRepository / InsightRepository の具体実装を生成する
  - [ ] @Environment に統一。EnvironmentKey を定義し（例: `\.sessionRepository`, `\.trackRepository`, `\.insightRepository`。※ Swift の KeyPath 記法はバックスラッシュ 1 つ）、ルート View に `.environment(\.sessionRepository, impl)` で渡す
  - [ ] 各 ViewModel が View 経由で @Environment から Repository を取得し、初期化引数で受け取る形で接続する
- **DoD**: 歌唱記録フロー（I-013）で RecordingViewModel が @Environment から SessionRepository / TrackRepository を取得し、保存処理が動作すること

---

### [I-008] Intent選択画面
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] Shout / Emo / Practice の3択UIを実装する（ボタン or セグメント）
  - [ ] 選択状態を ViewModel で保持し、歌唱記録フローに渡す
  - [ ] 選択後に歌唱記録入力画面へ遷移するナビゲーションを実装する

---

### [I-009] 歌唱記録入力画面
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] スコア入力UI（0〜100）を実装する（Slider または Stepper）
  - [ ] メモ入力UI（任意、TextField）を実装する
  - [ ] 保存ボタンを配置し、SessionRepository に保存する処理を実装する
  - [ ] 保存成功時に履歴へ遷移 or 完了表示を行う

---

### [I-010] 二重送信防止（UI層）
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] 保存ボタンタップ後に即座にボタンを非活性化する
  - [ ] 保存処理中に ProgressView を表示する
  - [ ] 処理完了まで画面のインタラクションをブロックする（オーバーレイ等）
  - [ ] 完了後にボタンを復帰させる

---

### [I-011] 二重送信防止（データ層）
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] 保存前に SessionRepository.exists(uuid) で重複チェックを行う
  - [ ] 既存の場合はスキップし、二重登録を防止する
  - [ ] クライアント生成の UUID を Idempotency Key として使用する
  - [ ] 冪等性が保証されることを確認する

---

### [I-012] 手動曲名入力画面
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] 曲名入力用の TextField を実装する
  - [ ] オフライン時に「ネットワークに接続してください」メッセージを表示する
  - [ ] 接続への導線（設定画面へのリンク、リトライボタン）を配置する
  - [ ] オンライン時は曲名を userEnteredName として Track に保存する

---

### [I-013] 歌唱記録フロー統合
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] 曲選択（インテントタブ or 手動入力）→ Intent選択 → 歌唱記録入力 → 保存の一連フローを接続する
  - [ ] RecordingViewModel で SessionRepository と TrackRepository を連携する
  - [ ] getOrCreate で Track を取得/作成し、SingingSession を保存する
  - [ ] フロー全体のナビゲーションと状態遷移を確認する

---

### [I-014] History画面
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] 歌唱セッションを日時降順で一覧表示する List を実装する
  - [ ] Intent フィルター（Shout/Emo/Practice）を画面上部に配置する
  - [ ] Phase 1 では userEnteredName で曲名を表示する（Track から取得）
  - [ ] セッション行をタップした場合のアクション（詳細表示等）を検討する

---

### [I-015] Infinite Scroll
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] fetchAll(limit: 20, offset) を用いたページネーションを実装する（1ページ20件。根拠: セルの高さ約80pt、iPhone画面に約10件表示 → 2画面分で余裕を持たせる）
  - [ ] スクロール末尾で追加読み込みをトリガーする
  - [ ] 大量データ（1000件以上）でもメモリ消費を抑制する
  - [ ] ローディングインジケータを表示する

---

### [I-016] Empty State（歌唱0件）
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [ ] 歌唱データ0件時に「まず1曲歌ってみよう！」メッセージを表示する
  - [ ] タブB（Spotify視聴履歴）または検索への誘導UIを配置する
  - [ ] インテントタブの Empty State として表示する

---

## Phase 2: インサイト・検索

### [I-017] インテントタブUI
- **Labels**: `priority:must`, `type:feat`, `phase:2-インサイト`
- **Tasks**:
  - [ ] タイムマシン表示領域をレイアウトする
  - [ ] マイアンセム表示領域をレイアウトする
  - [ ] InsightRepository からデータを取得する ViewModel を用意する
  - [ ] Empty State 時は I-016 の導線を表示する

---

### [I-018] タイムマシン表示
- **Labels**: `priority:must`, `type:feat`, `phase:2-インサイト`
- **Tasks**:
  - [ ] getTimeMachineRanking() で過去1ヶ月のランキングを取得する
  - [ ] 歌った回数降順でリスト表示する
  - [ ] Phase 2 では userEnteredName で曲名を表示する
  - [ ] ランキング内の曲をタップすると歌唱記録フローへ遷移する

---

### [I-019] マイアンセム表示
- **Labels**: `priority:must`, `type:feat`, `phase:2-インサイト`
- **Tasks**:
  - [ ] getMyAnthemRanking() で Intent 別ランキングを取得する
  - [ ] Shout/Emo/Practice ごとの回数ランキング・点数ランキングを表示する
  - [ ] セグメントまたはタブで Intent を切り替える
  - [ ] 曲をタップすると歌唱記録フローへ遷移する

---

### [I-020] 検索画面
- **Labels**: `priority:must`, `type:feat`, `phase:2-インサイト`
- **Tasks**:
  - [ ] 検索欄（TextField）と結果リストを配置する
  - [ ] ローカル結果を優先表示する UI を実装する
  - [ ] Spotify クレジット（「Powered by Spotify」ロゴ等）を検索結果領域に配置する
  - [ ] 検索画面へのナビゲーションを選曲画面から追加する

---

### [I-021] ローカル検索（インクリメンタル）
- **Labels**: `priority:must`, `type:feat`, `phase:2-インサイト`
- **Tasks**:
  - [ ] 入力と同時に TrackRepository.searchLocal(query) を呼び出す
  - [ ] userEnteredName に対する predicate で SwiftData 検索を行う
  - [ ] 歌った回数降順でソートして結果を表示する
  - [ ] デバウンス（任意）で過剰な検索を抑制する

---

### [I-022] 検索結果0件時の「手動で追加」
- **Labels**: `priority:must`, `type:feat`, `phase:2-インサイト`
- **Tasks**:
  - [ ] 検索結果0件（またはオフライン）時に「手動で追加して歌う」ボタンを表示する
  - [ ] 検索キーワードを引き継いで手動曲名入力画面へ遷移する
  - [ ] 手動入力画面で userEnteredName にキーワードをプリフィルする

---

## Phase 3: Spotify連携

### [I-023] OAuth 2.0 PKCE 実装
- **Labels**: `priority:must`, `type:feat`, `phase:3-Spotify`
- **Tasks**:
  - [ ] PKCE 用の code_verifier, code_challenge を生成する
  - [ ] 認証 URL を組み立て、Safari / ASWebAuthenticationSession で開く
  - [ ] コールバック URL から authorization code を取得する
  - [ ] トークンエンドポイントで access_token, refresh_token を取得し、Keychain に保存する

---

### [I-024] トークンリフレッシュ
- **Labels**: `priority:must`, `type:feat`, `phase:3-Spotify`
- **Tasks**:
  - [ ] トークン期限切れを検知する（expires_in または 401 レスポンス）
  - [ ] リフレッシュトークンで access_token を再取得する
  - [ ] 失敗時は再ログインを促す UI を表示する
  - [ ] 取得したトークンを Keychain に更新する

---

### [I-024A] TrackMetadataService / TrackMetadataCache 実装
- **Labels**: `priority:must`, `type:feat`, `phase:3-Spotify`
- **Tasks**:
  - [ ] actor TrackMetadataCache を実装する（maxAge: 24h, maxCount: 500）
  - [ ] TrackMetadataService を実装し、Track ID から GET /v1/tracks/{id} でメタデータを取得する
  - [ ] キャッシュヒット時はキャッシュから返し、ミス時は API 取得後にキャッシュに載せる
  - [ ] 検索 API / recently-played API のレスポンスで取得したメタデータもキャッシュに登録する

---

### [I-025] 最近再生した曲API
- **Labels**: `priority:must`, `type:feat`, `phase:3-Spotify`
- **Tasks**:
  - [ ] GET /v1/me/player/recently-played を呼び出す SpotifyAPIClient を実装する
  - [ ] 24時間以内の一時キャッシュ（インメモリ）に結果を保持する（永続化しない）
  - [ ] アプリ起動時・手動リフレッシュで API から再取得し、キャッシュを上書きする
  - [ ] 取得したメタデータを TrackMetadataCache に載せる

---

### [I-026] Spotify視聴履歴タブ
- **Labels**: `priority:should`, `type:feat`, `phase:3-Spotify`
- **Tasks**:
  - [ ] タブB に最近再生した曲の一覧を表示する
  - [ ] TrackMetadataCache 経由でメタデータ（曲名、アーティスト、アートワーク）を表示する
  - [ ] キャッシュが空の場合は「手動で曲名を入力して歌う」ボタンを表示する
  - [ ] 曲をタップすると歌唱記録フローへ遷移する

---

### [I-027] 検索API（Debounce 0.5秒）
- **Labels**: `priority:must`, `type:feat`, `phase:3-Spotify`
- **Tasks**:
  - [ ] 入力停止から 0.5 秒後に GET /v1/search?q=...&type=track を呼び出す Debounce を実装する
  - [ ] ローカル検索結果の下部に Spotify 検索結果を追加表示する
  - [ ] 検索結果のメタデータを TrackMetadataCache に載せる
  - [ ] オフライン時はローカル結果のみ表示する

---

### [I-028] オフライン時のフォールバック
- **Labels**: `priority:must`, `type:feat`, `phase:3-Spotify`
- **Tasks**:
  - [ ] ネットワーク未接続時は TrackMetadataCache からメタデータを取得して表示する
  - [ ] キャッシュにない場合は「曲情報を取得できません（ネットワーク接続が必要）」等を表示する
  - [ ] 履歴・インサイト・検索結果の各画面でオフライン時の表示を統一する
  - [ ] 手動入力曲（userEnteredName）は常に表示する

---

### [I-029] 指数バックオフ・リトライ
- **Labels**: `priority:must`, `type:feat`, `phase:3-Spotify`
- **Tasks**:
  - [ ] 429 / 5xx 時に指数バックオフ（1s → 2s → 4s...、最大60s）を実装する
  - [ ] Jitter（±25%）を加えて Thundering herd を回避する
  - [ ] 最大リトライ回数（3回）を設定する（根拠: バックオフ 1s→2s→4s で合計7秒。UX上の許容待ち時間の上限として妥当）
  - [ ] リトライ失敗時はユーザーに再試行を促す

---

### [I-030] APIエラー時の再試行UI
- **Labels**: `priority:must`, `type:feat`, `phase:3-Spotify`
- **Tasks**:
  - [ ] API エラー時にエラーメッセージを表示する
  - [ ] 「再試行」ボタンを配置し、リクエストを再実行できるようにする
  - [ ] 429 時は「しばらく待ってから再試行してください」等のメッセージを表示する
  - [ ] 401 失敗時は再ログイン案内へ遷移する

---

### [I-031] オンボーディング画面
- **Labels**: `priority:should`, `type:feat`, `phase:3-Spotify`
- **Tasks**:
  - [ ] 初回起動時に Spotify 連携を促すオンボーディング画面を表示する
  - [ ] 「スキップ」ボタンを配置し、ローカル機能のみで利用可能である旨を案内する
  - [ ] 連携完了後はオンボーディングを表示しない（UserDefaults 等でフラグ管理）
  - [ ] スキップ時も後から設定画面から連携できる導線を用意する

---

## Phase 4: 機能拡張・品質

### [I-032] 手動リフレッシュ
- **Labels**: `priority:must`, `type:feat`, `phase:4-拡張`
- **Tasks**:
  - [ ] 選曲画面にプルダウンリフレッシュ（refreshable）を実装する
  - [ ] または設定画面にリフレッシュボタンを配置する
  - [ ] リフレッシュ時に最近再生 API 等を再呼び出し、キャッシュを更新する
  - [ ] リフレッシュ中のローディング表示を行う

---

### [I-033] 設定画面
- **Labels**: `priority:should`, `type:feat`, `phase:4-拡張`
- **Tasks**:
  - [ ] Spotify 連携状態（連携済み/未連携）を表示する
  - [ ] リフレッシュボタン、ネットワーク導線を配置する
  - [ ] Spotify クレジット（「Powered by Spotify」ロゴ等）を配置する
  - [ ] プライバシーポリシー（Web）へのリンクを設置する（「データは端末内のみ保存、外部送信なし」旨）

---

### [I-034] JSON構造化ログ
- **Labels**: `priority:should`, `type:chore`, `phase:4-拡張`
- **Tasks**:
  - [ ] 全 API 通信で JSON 構造化ログを出力する（timestamp, request_id, endpoint, method, status_code, latency_ms, retry_count, user_id_hash, error_message）
  - [ ] ログ出力用のユーティリティまたはラッパーを実装する
  - [ ] デバッグビルドではコンソールに出力する

---

### [I-035] PIIマスキング
- **Labels**: `priority:must`, `type:chore`, `phase:4-拡張`
- **Tasks**:
  - [ ] user_id（Spotify User ID）を SHA-256 でハッシュ化してログに記録する
  - [ ] アクセストークン・リフレッシュトークンはログに含めない
  - [ ] ログ出力前に PII マスキング処理を適用する

---

### [I-036] VoiceOver対応
- **Labels**: `priority:could`, `type:feat`, `phase:4-拡張`
- **Tasks**:
  - [ ] 主要画面（選曲、履歴、歌唱記録入力、設定）に accessibilityLabel を設定する
  - [ ] ボタン・入力欄に適切なヒントを付与する
  - [ ] VoiceOver で操作できることを確認する

---

### [I-037] Dynamic Type対応
- **Labels**: `priority:could`, `type:feat`, `phase:4-拡張`
- **Tasks**:
  - [ ] テキストに .font(.body) 等のスケーラブルフォントを使用する
  - [ ] レイアウトがフォントサイズ変更で崩れないことを確認する
  - [ ] 設定でテキストサイズを変更して表示を検証する

---

### [I-038] 単体テスト（Repository）
- **Labels**: `priority:should`, `type:chore`, `phase:4-拡張`
- **Tasks**:
  - [ ] SessionRepository の save, fetchAll, exists のテストを実装する
  - [ ] TrackRepository の searchLocal, getOrCreate, incrementSingCount のテストを実装する
  - [ ] インメモリまたはテスト用 SwiftData コンテキストを使用する
  - [ ] 冪等性（二重保存で重複しない）のテストを含める

---

### [I-039] UIテスト（主要フロー）
- **Labels**: `priority:対象外`, `type:chore`, `phase:4-拡張`
- **Tasks**:
  - [ ] 歌唱記録保存フロー（曲選択→Intent→入力→保存）のスモークテストを1本のみ実装する
  - ※ 維持コストが高い E2E テストは対象外。Repository 単体テスト（I-038）を優先すること。