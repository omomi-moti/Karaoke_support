# V1 Issue 一覧（タスク統合版）

**Version**: 1.1  
**Created**: 2026-03-14  
**Updated**: 2026-03-25（I-014 追記・I-013 シート表示・I-018 / I-017 整理・I-017 ユニットテストの記述を反映）  
**前提フロー**: 曲入力 → Intent → スコア → 履歴 → ランキング

> **ドキュメントの位置づけ**: 本ファイルは V1 向け Issue/タスク体系の**単一の信頼できるソース（Source of Truth）**です。  
> `docs/issues.md` および `docs/issues_with_tasks.md` は全フェーズ（Phase 0〜4）の Issue 一覧を保持しますが、**V1 の範囲（I-001〜I-018 等）では本ファイルを正として参照**してください。  
> V1 関連の内容を更新する場合は、本ファイルを先に更新し、必要に応じて `issues_with_tasks.md` へ反映する運用とします。

---

## 技術選定メモ（V2移行を見据えた方針）

| 項目 | 選定 | 理由 |
|------|------|------|
| **DI 注入方法** | `@Environment` + カスタム EnvironmentKey | 憲法の「環境に注入」に準拠。Repository ごとに Key を切ることで、V2 で TrackMetadataService 等を追加する際に Key を追加するだけで済む。Protocol 型の注入も EnvironmentKey で対応可能。 |
| **TabView + NavigationStack** | 各タブごとに独立した NavigationStack | iOS 17+ のベストプラクティス。TabView 内側に NavigationStack を配置することで、タブ切り替え時もタブバーが表示され続ける。各タブのナビ履歴が独立し、V2 で検索タブ等を追加しても影響が局所化される。 |
| **選曲結果の受け渡し** | `SelectedTrack` を `SongsRecordingRoute.recording` に包み、`.sheet(item:)` で記録シートを表示 | 型安全で、V2 の検索・Spotify 履歴からの選曲も同じ型で扱える。`SongsRecordingRoute` は `Hashable`（将来の `NavigationPath` 利用にも備える）かつ **`Identifiable`**（`.sheet(item:)` 用）。 |
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

### [I-006] ネットワーク監視ユーティリティ
- **依存**: I-001
- **Labels**: `priority:must`, `type:feat`, `phase:0-基盤`
- **Tasks**:
  - [x] NWPathMonitor を用いた NetworkMonitor クラス/構造体を作成する
  - [x] 接続状態（online/offline）を @Observable で公開する
  - [x] アプリ起動時に監視を開始し、状態変化を検知できるようにする
  - [x] @Environment(\.networkMonitor) で参照できるよう EnvironmentKey を定義し、App 起点で注入する（I-012 等でオフライン判定に使用）

---

### [I-003] SessionRepository 実装
- **依存**: I-002
- **Labels**: `priority:must`, `type:feat`, `phase:0-基盤`
- **Tasks**:
  - [x] SessionRepository プロトコル（インターフェース）を Domain/Repositories に定義する
  - [x] SwiftDataSessionRepository を Data/SwiftData に実装する
  - [x] `saveNewRecordingSession` で歌唱記録を永続化する（SwiftData insert + `Track.singCount` 更新。**新規**の単一入口。I-011 冪等）
  - [x] `updateRecordingSession` で既存セッションを上書きする（編集用。`singCount` は増やさない。別 Track への差し替えは未対応でエラー）
  - [x] `deleteRecordingSession(uuid:)` でセッションを削除し、紐づく `Track.singCount` を 1 減らす（0 未満にしない）
  - [x] fetchAll(limit, offset) を実装する（日時降順）。offset はスキップ件数（0-based）。例: limit=20, offset=0 で 1〜20 件目、offset=20 で 21〜40 件目
  - [x] fetchByIntent(intent) を実装する
  - [x] exists(uuid) を実装する（冪等性チェック用）
- **編集フロー実装時の注意（履歴からの編集など）**:
  - 既存 `SingingSession` の変更は **`SessionRepository.updateRecordingSession`** のみ。`saveNewRecordingSession` は **新規 insert** と **同一 id の再送冪等**のみ（同 id では insert も `singCount` 加算も行わず、**プロパティの上書きはしない**）。
  - `RecordingSheetViewModel.save()` は現状 **新規のみ** `saveNewRecordingSession`。編集モードを追加する Issue では **`updateRecordingSession` を呼ぶ分岐**を必ず入れること（`saveNew` のまま同じ id を流すと冪等で黙って反映されない）。

---

### [I-004] TrackRepository 実装
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
  - [x] InsightRepository プロトコルを Domain/Repositories に定義する
  - [x] SwiftDataInsightRepository を Data/SwiftData に実装する
  - [x] fetchTimeMachineRanking() を実装する（過去1ヶ月、歌唱回数降順）
  - [x] fetchMyAnthemRankings(period:) を実装する（Intent別の回数・点数ランキング）
  - [x] SwiftData の @Query または FetchDescriptor で集計クエリを実装する

---

## Phase 1: タブ・曲入力〜保存

### [I-007] タブナビゲーション基盤
- **依存**: I-001
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [x] TabView で選曲画面（2タブ）、History、設定の3タブを構成する。各タブ内に独立した NavigationStack を配置する（タブバーが常に表示され、各タブのナビ履歴が独立する構成）
  - [x] タブA: インテント、タブB: Spotify視聴履歴のセグメント/タブUIを配置する。V1 ではタブB・設定は `EmptyPlaceholderView` 等の共通プレースホルダーを使用し、V2 で同型の View に差し替える
  - [x] History 画面への遷移をタブバーに追加する
  - [x] 設定画面への遷移をタブバーに追加する

---

### [I-007A] 依存性注入（DI）接続
- **依存**: I-002, I-003, I-004, I-005, I-007
- **Labels**: `priority:must`, `type:chore`, `phase:1-MVP`
- **Tasks**:
  - [x] App エントリで ModelContainer を参照（I-002 で登録済みの場合は確認のみ）
  - [x] SessionRepository / TrackRepository / InsightRepository の具体実装を生成する
  - [x] @Environment に統一。EnvironmentKey を定義し（例: `\.sessionRepository`, `\.trackRepository`, `\.insightRepository`。※ Swift の KeyPath 記法はバックスラッシュ 1 つ）、ルート View に `.environment(\.sessionRepository, impl)` で渡す
  - [x] 各 ViewModel が View 経由で @Environment から Repository を取得し、初期化引数で受け取る形で接続する
- **DoD**: 歌唱記録フロー（I-013）で RecordingViewModel が @Environment から SessionRepository / TrackRepository を取得し、保存処理が動作すること

---

### [I-012] 手動曲名入力画面
- **依存**: I-006, I-007
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **補足**: 実装方針を変更し、I-008/I-009 と統合した 1 枚の Recording Sheet 内で提供する
- **Tasks**:
  - [x] 曲名入力用の TextField を実装する
  - [x] 曲名が空文字の場合は保存処理に進まない。バリデーションで「曲名を入力してください」を表示する（getOrCreate に両方 nil を渡さないため）
  - [x] オフライン時に「ネットワークに接続してください」メッセージを表示する（ブロックはしない）。@Environment(\.networkMonitor) で接続状態を参照する
  - [x] 接続への導線（設定画面へのリンク、リトライボタン）を配置する
  - [x] 入力した曲名を `SelectedTrack(spotifyTrackId: nil, userEnteredName: 入力値)` に変換して保存フローで利用する

---

### [I-008] Intent選択画面
- **依存**: I-007
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **補足**: 実装方針を変更し、独立画面ではなく Recording Sheet 内の Intent セクションとして実装
- **Tasks**:
  - [x] Shout / Emo / Practice の3択UIを実装する（ボタン）
  - [x] 選択状態を ViewModel で保持し、歌唱記録フローに渡す
  - [x] 選曲結果（SelectedTrack）と Intent を同一シート内の保存処理に渡す
  - [x] Intent 選択後、そのまま歌唱記録入力（スコア/メモ）と保存が可能な統合UIを実装する

---

### [I-009] 歌唱記録入力画面
- **依存**: I-003, I-004, I-007, I-007A
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **補足**: 実装方針を変更し、I-012/I-008 と統合した 1 枚の Recording Sheet 内で提供する
- **Tasks**:
  - [x] スコア入力UI（0〜100）を実装する（Slider）
  - [x] メモ入力UI（任意、TextField）を実装する
  - [x] 保存ボタンを配置し、RecordingSheetViewModel 経由で TrackRepository.getOrCreate で Track を取得/作成し、SessionRepository.saveNewRecordingSession で歌唱記録を保存する
  - [x] 保存成功時は `selectedTab = .history` で履歴タブへ切り替える
  - [x] 保存失敗時は共通エラー表示コンポーネント（メッセージ「保存に失敗しました。もう一度お試しください」+ 再試行ボタン）を使用する（インライン表示）
- **手動QA**: 記録保存フローの確認手順は [`manual_qa_I008_I009_record_save.md`](./manual_qa_I008_I009_record_save.md) を参照

---

### [I-010] 二重送信防止（UI層）
- **依存**: I-009
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [x] 保存ボタンタップ後に即座にボタンを非活性化する
  - [x] 保存処理中に ProgressView を表示する
  - [x] 処理完了まで画面のインタラクションをブロックする（オーバーレイ等）
  - [x] 完了後にボタンを復帰させる

---

### [I-011] 二重送信防止（データ層）
- **依存**: I-003, I-009
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [x] 保存前に SessionRepository.exists(uuid) で重複チェックを行う
  - [x] 既存の場合はスキップし、二重登録を防止する
  - [x] クライアント生成の UUID を Idempotency Key として使用する
  - [x] 冪等性が保証されることを確認する（`Karaoke_supportTests/I011SessionIdempotencyTests.swift`）
- **MVP 仕様メモ（冪等の意味）**:
  - **同一 Idempotency Key（`SingingSession.id`）の再送**は、データ層では **既存なら insert・`singCount` 加算を行わず成功扱い**（＝**同一キーの再送は無視**）。
  - **V1 / MVP** では、保存失敗後の **再試行は「同じ入力内容でのやり直し」を推奨**とする。失敗後に曲名・スコア・Intent 等を変えてから再試行した場合、**既に同一キーで保存済み**だと **画面上の変更が DB に反映されないのに成功に見える**可能性がある（境界仕様）。詳細は [`manual_qa_I008_I009_record_save.md`](./manual_qa_I008_I009_record_save.md) の任意シナリオを参照。

---

### [I-013] 歌唱記録フロー統合
- **依存**: I-004, I-008, I-009, I-010, I-011, I-012
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [x] 選曲結果の受け渡し型 `SelectedTrack` を定義する。`spotifyTrackId: String?` と `userEnteredName: String?` を持ち、少なくとも片方が非空であること。Hashable。記録画面へは `SongsRecordingRoute.recording(SelectedTrack)` として **`.sheet(item:)`** で渡す。V2 で検索・Spotify 履歴からの選曲も同じ型で扱う
  - [x] 曲選択（手動入力 or ランキングタップ）→ Intent選択 → 歌唱記録入力 → 保存の一連フローを接続する
  - [x] RecordingViewModel で TrackRepository.getOrCreate で Track を取得/作成し、SessionRepository.saveNewRecordingSession で SingingSession を保存する
  - [x] ナビゲーション方針: 選曲タブ内は **NavigationStack（ルートのみ）+ `.sheet(item: SongsRecordingRoute?)`** で記録を表示（push ではない）。保存成功時は `selectedTab = .history` と **`presentedRecordingRoute = nil`**（シート解除）。遷移図は [`v1_navigation_songs_recording.md`](./v1_navigation_songs_recording.md)
  - [x] フロー全体のナビゲーションと状態遷移を確認する
- **参照**: 遷移図・関連ファイル一覧は [`v1_navigation_songs_recording.md`](./v1_navigation_songs_recording.md)

---

## Phase 1: 履歴・Empty・ランキング

### [I-014] History画面
- **依存**: I-003, I-007
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **UI 参考（カード一覧）**:
  - **背景**: ダークグラデーション（黒〜深灰）
  - **行**: 角丸カード（半透明フィル）。**左**: 1行目＝曲名、2行目＝歌唱日時（`performedAt`、日本語ロケール）。**Intent** はピルバッジ（例: 🔥 Shout / 🌙 Emo / 🎤 Practice）。**右**: 大きなスコア数値（小数1桁）+ ラベル「SCORE」
  - **フィルター**: 画面上部に横スクロールチップ（すべて / Shout / Emo / Practice）
  - **V1 の曲名**: `TrackDisplayTitle.primary(for:)`（`userEnteredName` → Spotify ID 短縮 →「不明」）。アーティスト名は **V2**（Spotify メタデータ）で追加
- **Tasks**:
  - [x] 歌唱セッションを日時降順で一覧表示する List を実装する（**「すべて」も Intent も同一上限**で `fetchAll(limit:offset:)` の直近ウィンドウに揃え、Intent はその結果をメモリ上で `filter`。直近 N 件に該当が無いと空表示。初回は最大200件、I-015 でページネーション）
  - [x] Intent フィルター（Shout/Emo/Practice）を画面上部に配置する（`HistoryFilterBarView`）
  - [x] V1 では `TrackDisplayTitle` で曲名を表示する。V2 で TrackMetadataCache 経由に切り替える際は同ヘルパーを拡張または差し替えで局所化する
  - [x] セッション行をタップした場合のアクション（V1では未実装で可）— 行の `onTapGesture` は未接続
  - [x] スワイプで削除（`SessionRepository.deleteRecordingSession` + `HistoryViewModel.deleteSession`）

#### 本ブランチ（`main` 差分）レビュー: リスク・技術負債

> 以下は **致命的バグの可能性** と **今後の負債** の指摘。優先度はチームで再評価すること。

| 種別 | 内容 |
|------|------|
| **競合リスク** | ~~削除と `load` の世代未整合~~ **対応済**（`deleteSession` 開始時に `loadGeneration` を進め、`applySessions` 前に `myGeneration` / `requestedFilter` でガード。ずれたら `load()` で再同期）。 |
| **UX / 初期表示** | ~~`HistoryRootView` が `onAppear` まで遅延~~ **対応済**（`HistoryListContainerView` で `State(initialValue:)` により初回描画から VM を生成。真っ黒 1 フレームを解消）。 |
| **プレビュー制限** | `PreviewSessionRepository` は `updateRecordingSession` 成功後も `fetchAll` が静的サンプルのため **編集内容が一覧に出ない**（コメント済み）。編集 UI をプレビューするなら **簡易インメモリストア**が別途必要。 |
| **Repository 挙動** | `fetchByIntent` を「直近ウィンドウ `fetchAll` + メモリ filter」に統一。**直近 N 件に該当 Intent が少ないと一覧が空**になるのは仕様だが、N や文言のユーザー説明が必要。I-015 ページネーション時は **DB 側 sort/filter 戦略の再検討**が負債になりうる。 |
| **色・トークン** | スコア色・背景グラデが **リテラル `Color`**。ダークモード固定・アクセシビリティ（コントラスト）・テーマ一元化が未着手 → **I-014-A**。 |
| **ソート** | 現状は **日時降順のみ**（`fetchAll` の SortDescriptor に依存）。スコア順 UI なし → **I-014-B**。 |
| **履歴からの編集** | `SessionRepository.updateRecordingSession` は実装済みだが、`RecordingSheetViewModel.save()` は **新規のみ**（コメント済み）。履歴行タップ未接続 → **I-014-C**。 |

---

#### I-014 分岐タスク（色・ソート・履歴からの更新）

以下は **I-014 の拡張**として追記する。親 Issue は I-014 のまま、分岐を **I-014-A / B / C** で管理する。

##### [I-014-A] 色・テーマ（履歴画面）

- [x] 履歴の背景グラデーション・カード背景・枠線・スコア色・バッジ色を **`Asset`（Color Set）または `AppTheme` / `Environment` 値**に集約し、View からリテラルを排除する（**`AppColor` + `Assets` のセマンティック名**。録音スコア表示も `AppAccentScore` に揃えた）
- [x] ダークモードを正式サポートする場合は **ライト/ダーク** 用の色定義を分ける（現状はダーク寄せ固定のため、仕様をドキュメント化してもよい）→ **未対応を `docs/design/color_tokens_v1.md` に明記**
- [x] テキスト／背景の **コントラスト** を確認し、必要なら WCAG 目安を `docs/` にメモする → **同ドキュメントに確認方針を記載**（詳細検証はチーム判断）
- [x] `AccentColor` や Tab との **視覚的一貫性** を確認する → **`AccentColor.colorset` を `AppAccentScore` と同一の sRGB に統一**

##### [I-014-B] ソート（日付順・点数順）

- [x] 仕様を固定する: **既定＝歌唱日時（`performedAt`）降順**（現状）、ユーザー切替で **スコア降順 / スコア昇順**（必要なら日付昇順）を追加するか決める → **`HistorySortOrder`**: 日付新/古・点数高/低の4種（V1 はメモリ整列）
- [x] UI: ツールバーメニュー・セグメント・またはフィルター行直下の **ソートコントロール**を配置する（履歴画面内の導線をワイヤーまたは本文で決める） → **フィルター行直下に `HistorySortControlView`（メニュー形式 Picker）**
- [x] `HistoryViewModel`: 表示配列は値型のまま **`sessions` の並べ替え**で実装するか、`Repository` に sort パラメータを足すか方針を決める（**I-015 ページネーション**と整合するなら fetch 側 sort が有利な場合あり） → **V1 は `fetchAll` 後に値型へ写し `filter → sort`（I-015 で fetch 側 sort を検討可）**
- [x] **Intent フィルター適用後**にソートする（`filter → sort` の順をコード・ドキュメントの両方で明文化）
- [x] ソート変更時に **空状態メッセージ**が誤解を招かないか確認する → **件数0のときは従来どおり（並び替えは表示の順のみに影響）**

##### [I-014-C] 履歴からの記録の更新（編集）

- [x] 行タップ（またはスワイプ補助アクション）で **編集フロー**へ遷移するナビゲーションを定義する（`NavigationPath` / sheet / フルスクリーンのいずれか） → **`NavigationStack` + 行タップ `NavigationLink` + リードスワイプ「編集」**
- [x] 既存 `SingingSession` を編集対象として **`RecordingSheetViewModel` に編集モード**を追加する（初期値に intent / score / memo / performedAt を注入）
- [x] `save()` 内で **新規 → `saveNewRecordingSession`**、**既存更新 → `updateRecordingSession`** を分岐する（**I-003** の注意: 同 id を `saveNew` に流さない）
- [x] 保存成功後に **履歴一覧を `load()` または同等の再取得**で同期する
- [x] 失敗時は **エラー表示・再試行**（憲法 FR-011）を既存パターンに合わせる
- [x] `PreviewSessionRepository` を使うプレビューでは、**編集結果が一覧に反映されない**制約を引き続き明示するか、プレビュー用ストアを拡張する → **ドキュメントコメントで明示（静的 `fetchAll` のため）**

---

### [I-015] Infinite Scroll
- **依存**: I-014
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [x] `fetchAll(limit: 20, offset)` を用いたページネーションを実装する。offset = pageIndex * 20（0-based）。I-003 の offset 仕様に準拠 → **`HistoryViewModel` の `pageSize = 20`・`fetchPage`。**「すべて」は `fetchAll(20, offset)`。Intent は直近ウィンドウ内でメモリ絞り込み＋同一ウィンドウのキャッシュスライス（`SwiftDataSessionRepository`）
  - [x] スクロール末尾で追加読み込みをトリガーする → **リスト行の出現＋末尾付近（下から5行以内）で `loadNextPageIfNeeded`**
  - [x] 大量データ（1000件以上）でもメモリ消費を抑制する → **表示スナップショットは最大 500 行で打ち切り**（`HistoryViewModel.maxDisplayedSessionRows`）。Intent 用は DB 再読込の重複をキャッシュで抑制
  - [x] ローディングインジケータを表示する → **初回 `isLoading`、追加 `isLoadingNextPage` + `ProgressView`**

---

### [I-016] Empty State（歌唱0件）
- **依存**: I-005, I-007
- **Labels**: `priority:must`, `type:feat`, `phase:1-MVP`
- **Tasks**:
  - [x] 歌唱データ0件時に「まず1曲歌ってみよう！」メッセージを表示する → **履歴「すべて」かつ 0 件時に ``SingingEmptyStateView``（文言は ``SingingEmptyStateCopy``）**
  - [x] 「手動で曲名を入力して歌う」への導線を NavigationLink または Button で配置する。タップで手動曲名入力画面へ遷移 → **同一 View 内の Button。``navigateToManualRecording``（App Environment）で選曲タブへ切替え + ``manualRecordingNavigationTick`` により ``SongsRootView`` が `presentedRecordingRoute = .manualRecording` で記録シートを開く**
  - [x] Empty State 用の再利用可能な View コンポーネントとして実装する。I-017 のインテントタブがデータ0件時にこれを表示する → **`SingingEmptyStateView` / `SingingEmptyStateCopy`**

---

## Phase 2: インサイト・検索

### [I-017] インテントタブUI
- **依存**: I-005, I-007, I-016
- **Labels**: `priority:must`, `type:feat`, `phase:2-インサイト`
- **Tasks**:
  - [x] タイムマシン表示領域をレイアウトする → **ヘッダー + 紫グラデの `TimeMachineInsightCardView`。「振り返る」で `TimeMachineRankingSheetView`（`fetchTimeMachineRanking()`）**
  - [x] マイアンセム表示領域をレイアウトする → **インディゴグラデの `MyAnthemInsightCardView`。「聴く」で `MyAnthemRankingSheetView`（`fetchMyAnthemRankings`）**
  - [x] InsightRepository からデータを取得する ViewModel を用意する → **`IntentTabViewModel`（`IntentTabContainerView` が生成）**
  - [x] 歌唱データ0件時は I-016 の Empty State コンポーネントを表示する → **`sessionRepository.fetchAll(limit:1)` で判定し `SingingEmptyStateView`**
- **ユニットテスト**（`Karaoke_supportTests`）:
  - **`IntentTabViewModelTests`**: `load()` の成功（`Preview*` Repository）・セッション 0 件で Insight 未呼び出し・タイムマシン／先頭 `fetchAll` 失敗時のエラーメッセージ・**並行 `load()` で最新試行のみ Insight を取得**（`loadGeneration`）・**`computeMonthStats`**（今月のみカウント・600 件でページング・翌月境界除外）。スタブは `SessionRepositoryProtocol` の **日時降順**に合わせて `performedAt` でソート。
  - **`InsightTrackRowTitleTests`**: `InsightTrackRowTitle.text` の優先順位（手入力名 / Spotify ID / 「曲名未設定」）・`InsightTrackCountRanking` / `InsightTrackScoreRanking` の **`makeSelectedTrack()`**（同一メタデータの一致・空白トリム・両方空で `nil` 等）。
- **任意フォロー**: タイムマシン／マイアンセムの2シートを **`enum` + `.sheet(item:)` 一本化**し、両 `Bool` が同時に true になり得ることを防ぐ案 → [`v1_navigation_songs_recording.md`](./v1_navigation_songs_recording.md)「インテントタブのランキングシート」

---

### [I-018] タイムマシン表示
- **依存**: I-005, I-017
- **Labels**: `priority:must`, `type:feat`, `phase:2-インサイト`
- **補足**: タイムマシン **ランキングの取得・一覧シート・タップで記録シート**は **I-017**（`TimeMachineRankingSheetView`・`IntentTabViewModel`）で実装済み。曲名は **`InsightTrackRowTitle`** で統一（`userEnteredName` 優先・フォールバック）。本 Issue のチェックは **I-017 との重複を解消**し、残差は **文言・専用画面の切り出し** 等を別タスクで扱う。
- **Tasks**:
  - [x] fetchTimeMachineRanking() で過去1ヶ月のランキングを取得する → **I-017 / `IntentTabViewModel`・`TimeMachineRankingSheetView`**
  - [x] 歌った回数降順でリスト表示する → **I-017 / `fetchTimeMachineRanking` と `fetchAll` の並び順に準拠したシート一覧**
  - [x] V1 では曲名を一貫表示する → **`InsightTrackRowTitle`（I-017 のランキング行）**
  - [x] ランキング内の曲をタップすると `SelectedTrack` を組み立て、`SongsRecordingRoute.recording` 経由で **記録シート**を開く → **I-017 / `SongsRootView` の `onSelectTrack`**

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
| 18 | ランキング内の曲をタップすると記録シート（歌唱記録フロー）が開く | □ |
| 19 | 曲選択 → Intent → スコア → 保存 → 履歴 が一連で動作する | □ |
