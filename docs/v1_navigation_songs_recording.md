# 選曲タブ × 歌唱記録のナビゲーション（I-013）

## 方針

- **単一の `NavigationStack`** を選曲タブ内に持つ（`SongsRootView`）。`RootView` の選曲タブ側では **外側に `NavigationStack` を重ねない**（二重スタック回避）。
- **状態**: `@State private var path = NavigationPath()` に `SongsRecordingRoute` を積む。
- **保存成功**: `path = NavigationPath()` でスタックをリセットし、親から `selectedTab = .history`（`RootView`）で履歴タブへ。

## ルート型

| ルート | 意味 |
|--------|------|
| `manualRecording` | ツールバー「記録を追加」→ 手動入力から Intent・スコアへ |
| `recording(SelectedTrack)` | ランキング等で確定済みの曲から同じ記録 UI へ（V2 の検索・Spotify 履歴も同型） |

## 遷移図（テキスト）

```
[選曲ルート]
    │
    ├─(+) 記録を追加 ──► manualRecording ──► RecordingSheetContainerView(seed: .mode(.manual))
    │
    └─(ランキングスタブ等) recording(SelectedTrack) ──► RecordingSheetContainerView(seed: .selectedTrack)
                              │
                              ▼
                    Intent / スコア / メモ / 保存
                              │
                              ▼ 成功
                    path クリア + 履歴タブ
```

## 関連コード

- `Sources/Presentation/Songs/SongsRootView.swift` — `NavigationStack(path:)` と `navigationDestination`。ランキング未実装時のスタブは `private static let stubRankingSample`（`SelectedTrack`）に集約し、`recording(SelectedTrack)` で push（`raw_spec` 6.7 の例外。I-018 でリスト行に置き換え）
- `Sources/Presentation/Songs/SongsRecordingRoute.swift` — ルート列挙
- `Sources/Presentation/Recording/RecordingSheetContainerView.swift` — `presentation: .navigationStack` / `.sheet`
- `Sources/Presentation/Recording/RecordingSheetViewModel.swift` — `SelectedTrack` から `TrackInputState` へ変換。不変条件に反する `(nil, nil)` は `assertionFailure` + 手動モード + インラインエラー（`raw_spec` 6.7。本番では `fatalError` しない）
- `Sources/Presentation/Root/RootView.swift` — `onSavedMoveToHistory` で `selectedTab = .history`
