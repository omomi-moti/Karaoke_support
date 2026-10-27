# 歌唱記録シートのナビゲーション（I-013 / iOS 26 タブバー移行）

## 方針

- **シートは `RootView` に 1 つだけ**置く。`TabView` に `.sheet(item: $sheet, onDismiss:)` を付け、記録シート（`RecordingSheetContainerView`）と保存直後のシート（`AfterSaveRecommendationSheetView`）を切り替える（ADR 0025）。選曲・履歴・検索のどのタブから開いても同じシートを使う。
- **歌唱記録 UI は `NavigationStack` の push では出さない**。push で `NavigationPath` を空にして pop すると、必ず一度 **下のルートが露出**する。保存後に履歴タブへ切り替えるときの「一瞬チラつき」を避けるため、**シートの dismiss** で閉じる。
- 各タブの `NavigationStack` はタブ内に独立して持つ（選曲は `SongsRootView`、履歴は `HistoryListContainerView`、設定・検索は `RootView` の `Tab` 内）。記録シートはどのタブのスタックにも積まない。
- 選曲タブ（`SongsRootView`）は、選曲画面ができるまで、記録がないときと同じ空の状態を出す（#126。タイムマシン・マイアンセム・今月の統計は ADR 0038 で消した）。V1 にあった「インテント / Spotify」のセグメントは撤去した。

## シートの開き方

`RootView` 内の `RootSheet`（`id: UUID` + `kind`）で表示する。`kind` は記録シート（`.recording(RecordingSessionSeed)`）か保存直後のシート（`.afterSave(AfterSaveSheetContent)`）。開くたびに新しい `id` を採番するため、同じ曲を続けて選んでもシートは作り直される。

開き方はすべて `present()` を通す。シートが出ていなければその場で出し、閉じている途中なら閉じ終わって（`onDismiss`）から出し、別のシートが開いていれば閉じてから出す。閉じている途中に次のシートを出すと、SwiftUI が出し損ねることがあるため。閉じている途中にもう一度押されたとき（カードの二度押しなど）も、予約し直すだけにして、閉じ終わってから 1 枚だけ出す（`closeSheet(then:)`）。

| 起点 | 呼び出し | `seed` |
|------|----------|--------|
| 選曲・履歴タブ右下の ＋ ボタン | `presentManualRecording()` | `.mode(.manual)` |
| 空状態の「手動で曲名を入力して歌う」（選曲・履歴） | `EnvironmentValues.navigateToManualRecording` → `presentManualRecording()` | `.mode(.manual)` |
| 検索タブ（`Tab(role: .search)`）の結果行 | `SearchContainerView(onSelectTrack:)` → `presentRecording(_:)` | `.selectedTrack(SelectedTrack)` |
| 保存直後のシートの提案カード | `recordRecommendation(_:intent:)`（保存直後のシートを閉じてから開く） | `.selectedTrack(SelectedTrack, intent:, source: .suggestion)`（保存した記録の気分を入れて開く。曲を変えずに保存すると、提案からの記録になる・ADR 0034） |

`navigateToManualRecording` は以前は「選曲タブへ切替 + tick で `SongsRootView` にシートを開かせる」方式だったが、シートを `RootView` に集約したため **その場で開く**だけになった。

## 保存成功時

1. `RecordingSheetContentView.attemptSave()` 成功時に、保存した記録の要約（`SavedRecording`）を付けて `onSaved(_:)` を呼ぶ。
2. `RootView.handleSaved(_:)` で **シートを閉じ**、**`historyReloadTick += 1`**。シートが**閉じ終わってから**（`onDismiss`）`selectedTab = .history`（アニメーションなし）にする。閉じている途中に切り替えると、後ろの画面が急に変わって見えるため（ADR 0032）。
3. `RecordingSheetContentView` は **`dismiss()`** も呼ぶ（二重の閉じ方だが問題にならない）。
4. `AfterSaveRecommendationViewModel.prepare(for:)` で候補を読み、中身が返ったときだけ保存直後のシートを出す。新規の記録で候補が 1 件以上あるときだけで、編集して更新したとき・候補が 0 件のとき・読み込みに失敗したときは出さない（ADR 0024）。出すのは履歴タブへ移ってから 1 秒たってから（`afterSaveSheetDelay`。履歴に記録が増えたのが見えてから出すため・ADR 0032）。中身の読み込みと履歴タブへの移動は、どちらが先に終わってもよい。候補を待っている間に別のシートが開かれた・予約されたとき（保存した直後に＋を押した、など）も出さず、そちらを優先する（ADR 0025）。

### `historyReloadTick` が必要な理由

履歴一覧は値型スナップショットを表示しており、再読み込みは `HistoryListView` の `.task(id:)` だけが担う。以前は記録シートが選曲タブにしかなく、保存後のタブ切替で履歴が「表示される」ことで `.task` が動いていた。**履歴タブ上でシートを開いて保存すると、タブ切替も再表示も起きない**ため、保存回数を `EnvironmentValues.historyReloadTick` で渡し、`.task(id: ReloadKey(filter:tick:))` に含めて再読み込みさせる。

## 遷移図（テキスト）

```
[選曲タブ] ──(＋ / 空状態)────────┐
[選曲タブ] ──(ランキング行)───────┤
[履歴タブ] ──(＋ / 空状態)────────┤──► RootView.sheet（.recording）
[検索タブ] ──(検索結果行)─────────┘            │
                                               ▼
                         .sheet ──► RecordingSheetContainerView(seed:, presentation: .sheet)
                                               │
                                               ▼
                                 Intent / スコア / メモ / 保存
                                               │
                                               ▼ 成功
                        シート解除 + historyReloadTick += 1
                                               │
                                               ▼ 閉じ終わってから
                                           履歴タブへ
                                               │
                                               ▼ 新規で候補があるとき（履歴タブへ移ってから 1 秒後）
                         .sheet ──► AfterSaveRecommendationSheetView
                                   │                    │
                                   ▼ カード             ▼ あとで
                     記録シート（曲名＋気分入り）       シート解除
```

## 関連コード

- `Sources/Presentation/Root/RootView.swift` — `TabView`（iOS 26 `Tab` API）+ 記録シートと保存直後のシートの切り替え + ＋ボタン + `historyReloadTick`
- `Sources/Presentation/AfterSave/` — 保存直後のシート（`AfterSaveRecommendationSheetView`）と、候補を用意する `AfterSaveRecommendationViewModel`（#115）
- `Sources/Presentation/Songs/SongsRootView.swift` — 選曲タブの `NavigationStack`（ルートのみ）。記録は `onSelectTrack` で `RootView` に委譲
- `Sources/Presentation/Search/SearchContainerView.swift` — 検索タブ本体（`.searchable`）。選択は `onSelectTrack` で `RootView` に委譲
- `Sources/App/Environment/HistoryReloadEnvironment.swift` — `historyReloadTick`
- `Sources/Presentation/Recording/Sheet/RecordingSheetContainerView.swift` — `RootView` の記録シートの中身。新規・曲を選んだとき・履歴からの編集（`seed: .editSession`）のどれもここから開く（ADR 0022）
- `Sources/Presentation/Recording/Sheet/RecordingSheetContentView.swift` — 保存成功時の `onSaved` と `dismiss()`

## 履歴タブのナビゲーション（I-014-C / I-019）

履歴タブは `NavigationStack(path:)` + `navigationDestination(for: HistoryRoute.self)` の 1 経路。遷移先は曲詳細だけで、編集（リードスワイプ「編集」）は Environment の `navigateToEditRecording` で `RootView` の記録シートを開く（ADR 0022）。

| ケース | 起点 | 遷移先 |
|--------|------|--------|
| `trackDetail(trackId:title:)` | 行タップ（`NavigationLink(value:)`） | `TrackDetailContainerView`（読み取り専用） |

- 曲名は行のスナップショットから `title` としてルートに載せる。曲詳細のヘッダーを追加クエリなしで描画するため
- 編集の保存後は、新規と同じく `RootView` がシートを閉じて `historyReloadTick` を増やし、一覧を読み込み直す。保存直後のシートは出さない
