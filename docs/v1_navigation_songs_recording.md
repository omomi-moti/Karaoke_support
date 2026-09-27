# 歌唱記録シートのナビゲーション（I-013 / iOS 26 タブバー移行）

## 方針

- **記録シートは `RootView` に 1 つだけ**置く。`TabView` に `.sheet(item: $recordingSheetItem)` を付け、`RecordingSheetContainerView` をモーダル表示する（`presentation: .sheet`）。選曲・履歴・検索のどのタブから開いても同じシートを使う。
- **歌唱記録 UI は `NavigationStack` の push では出さない**。push で `NavigationPath` を空にして pop すると、必ず一度 **下のルートが露出**する。保存後に履歴タブへ切り替えるときの「一瞬チラつき」を避けるため、**シートの dismiss** で閉じる。
- 各タブの `NavigationStack` はタブ内に独立して持つ（選曲は `SongsRootView`、履歴は `HistoryListContainerView`、設定・検索は `RootView` の `Tab` 内）。記録シートはどのタブのスタックにも積まない。
- 選曲タブは **インテント（`IntentTabContainerView`）のみ**を表示する。V1 にあった「インテント / Spotify」のセグメントは撤去した（Spotify 視聴履歴の配置は V2 の I-026 で再検討）。

## シートの開き方

`RootView` 内の `RecordingSheetItem`（`id: UUID` + `seed: RecordingSessionSeed`）で表示する。開くたびに新しい `id` を採番するため、同じ曲を続けて選んでもシートは作り直される。

| 起点 | 呼び出し | `seed` |
|------|----------|--------|
| 選曲・履歴タブ右下の ＋ ボタン | `presentManualRecording()` | `.mode(.manual)` |
| 空状態の「手動で曲名を入力して歌う」（選曲・履歴） | `EnvironmentValues.navigateToManualRecording` → `presentManualRecording()` | `.mode(.manual)` |
| タイムマシン／マイアンセムのランキング行 | `SongsRootView(onSelectTrack:)` → `presentRecording(_:)` | `.selectedTrack(SelectedTrack)` |
| 検索タブ（`Tab(role: .search)`）の結果行 | `SearchContainerView(onSelectTrack:)` → `presentRecording(_:)` | `.selectedTrack(SelectedTrack)` |

`navigateToManualRecording` は以前は「選曲タブへ切替 + tick で `SongsRootView` にシートを開かせる」方式だったが、シートを `RootView` に集約したため **その場で開く**だけになった。

## 保存成功時

1. `RecordingSheetContentView.attemptSave()` 成功時に `onSavedMoveToHistory()` を呼ぶ。
2. `RootView` で **`recordingSheetItem = nil`**（シート解除）、**`historyReloadTick += 1`**、`selectedTab = .history`（アニメーションなし）。
3. `RecordingSheetContentView` は `presentation == .sheet` のとき **`dismiss()`** も呼ぶ（二重の閉じ方だが問題にならない）。

### `historyReloadTick` が必要な理由

履歴一覧は値型スナップショットを表示しており、再読み込みは `HistoryListView` の `.task(id:)` だけが担う。以前は記録シートが選曲タブにしかなく、保存後のタブ切替で履歴が「表示される」ことで `.task` が動いていた。**履歴タブ上でシートを開いて保存すると、タブ切替も再表示も起きない**ため、保存回数を `EnvironmentValues.historyReloadTick` で渡し、`.task(id: ReloadKey(filter:tick:))` に含めて再読み込みさせる。

## 遷移図（テキスト）

```
[選曲タブ] ──(＋ / 空状態)────────┐
[選曲タブ] ──(ランキング行)───────┤
[履歴タブ] ──(＋ / 空状態)────────┤──► RootView.recordingSheetItem
[検索タブ] ──(検索結果行)─────────┘            │
                                               ▼
                         .sheet ──► RecordingSheetContainerView(seed:, presentation: .sheet)
                                               │
                                               ▼
                                 Intent / スコア / メモ / 保存
                                               │
                                               ▼ 成功
                        シート解除 + historyReloadTick += 1 + 履歴タブへ
```

## 関連コード

- `Sources/Presentation/Root/RootView.swift` — `TabView`（iOS 26 `Tab` API）+ 記録シート + ＋ボタン + `historyReloadTick`
- `Sources/Presentation/Songs/SongsRootView.swift` — 選曲タブの `NavigationStack`（ルートのみ）。記録は `onSelectTrack` で `RootView` に委譲
- `Sources/Presentation/Search/SearchContainerView.swift` — 検索タブ本体（`.searchable`）。選択は `onSelectTrack` で `RootView` に委譲
- `Sources/App/Environment/HistoryReloadEnvironment.swift` — `historyReloadTick`
- `Sources/Presentation/Recording/Sheet/RecordingSheetContainerView.swift` — `presentation: .sheet`（`RootView` から開くとき）。履歴タブの編集は **別経路**で `NavigationStack` + `presentation: .navigationStack` のまま
- `Sources/Presentation/Recording/Sheet/RecordingSheetContentView.swift` — 保存成功時の `onSavedMoveToHistory` / `.sheet` 時の `dismiss()`

## 履歴タブのナビゲーション（I-014-C / I-019）

履歴タブは `NavigationStack(path:)` + `navigationDestination(for: HistoryRoute.self)` の 1 経路で、2 つの遷移先を **enum で分岐**する。

| ケース | 起点 | 遷移先 |
|--------|------|--------|
| `trackDetail(trackId:title:)` | 行タップ（`NavigationLink(value:)`） | `TrackDetailContainerView`（読み取り専用） |
| `editSession(sessionId:)` | リードスワイプ「編集」 | `RecordingSheetContainerView(presentation: .navigationStack)` |

- どちらも `UUID` を運ぶため、`navigationDestination(for: UUID.self)` のままだと **行タップで編集が開く**取り違えが型チェックを素通りする。`HistoryRoute` で区別している
- 曲名は行のスナップショットから `title` としてルートに載せる。曲詳細のヘッダーを追加クエリなしで描画するため
- 編集の保存成功時のみ `navigationPath.removeLast()` で pop し、`viewModel.load()` で一覧を再同期する

## インテントタブのランキングシート（I-017）

- **タイムマシン**（`TimeMachineRankingSheetView`）と **マイアンセム**（`MyAnthemRankingSheetView`）は、`IntentTabInsightView` 上で **`.sheet(isPresented:)` を2つ**（`showTimeMachineSheet` / `showMyAnthemSheet`）使っている。通常 UI では同時に開かないが、**両方 `true` になり得ると挙動が曖昧になりうる**。必要なら **`enum ActiveRankingSheet` + `.sheet(item:)` 一本化**を検討する（任意・優先度低）。
