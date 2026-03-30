# 選曲タブ × 歌唱記録のナビゲーション（I-013）

## 方針

- **単一の `NavigationStack`** を選曲タブ内に持つ（`SongsRootView`）。ここでは **セグメント（インテント / Spotify）とルートコンテンツ**のみを載せる。`RootView` の選曲タブ側では **外側に `NavigationStack` を重ねない**（二重スタック回避）。
- **歌唱記録 UI** は **`NavigationStack` の push では出さない**。`@State private var presentedRecordingRoute: SongsRecordingRoute?` と **`.sheet(item: $presentedRecordingRoute)`** で `RecordingSheetContainerView` をモーダル表示する（`presentation: .sheet`）。
- **理由（UX）**: push で `NavigationPath` を空にして pop すると、必ず一度 **下のルート（インテント一覧）が露出**する。保存後に履歴タブへ切り替えるときの「一瞬チラつき」を避けるため、**シートの dismiss** で閉じる。

## ルート型 `SongsRecordingRoute`

`Hashable`（将来の `NavigationPath` 利用にも備える）に加え、**`.sheet(item:)`** 用に **`Identifiable`** を実装し、`id` を定義する。

| ルート | 意味 |
|--------|------|
| `manualRecording` | ツールバー「記録を追加」→ 手動入力から Intent・スコアへ |
| `recording(SelectedTrack)` | ランキング等で確定済みの曲から同じ記録 UI へ（V2 の検索・Spotify 履歴も同型） |

### `Identifiable.id` の注意（`.sheet(item:)`）

SwiftUI は **`id` が変わったか**でシートの同一性を判断する。現状は `recording` の `id` を **`recording|\(spotifyTrackId)|\(userEnteredName)` 風に連結**しており、**区切り文字と内容の組み合わせで理論上衝突**し得る（例: `spotifyTrackId` が `a|b` で名前が空 vs `a` と `b`）。**実害は稀**だが、再表示がおかしい報告があれば **`String(reflecting:)`、安定ハッシュ、または表示用とは別の UUID** などに変更する。

## 保存成功時

1. `RecordingSheetContentView.attemptSave()` 成功時に `onSavedMoveToHistory()`（親で `selectedTab = .history`）。
2. `SongsRootView.handleRecordingSaved()` で **`presentedRecordingRoute = nil`**（シートを閉じる）。
3. `RecordingSheetContentView` は `presentation == .sheet` のとき **`dismiss()`** も呼ぶ（二重の閉じ方だが問題にならない）。

## 履歴からの「手動で記録」

`EnvironmentValues.navigateToManualRecording` で **`RootView` が選曲タブ選択 + `manualRecordingNavigationTick` を増加**し、`SongsRootView` の `onChange` で **`presentedRecordingRoute = .manualRecording`**（旧 `NavigationPath` に積む方式から変更）。

## 遷移図（テキスト）

```
[選曲ルート（NavigationStack のルートのみ）]
    │
    ├─(+) 記録を追加 ──► presentedRecordingRoute = .manualRecording
    │                              │
    │                              ▼
    │                    .sheet ──► RecordingSheetContainerView(seed: .mode(.manual), presentation: .sheet)
    │
    └─(ランキング等) presentedRecordingRoute = .recording(SelectedTrack)
                                           │
                                           ▼
                                 .sheet ──► RecordingSheetContainerView(seed: .selectedTrack, presentation: .sheet)
                                           │
                                           ▼
                                 Intent / スコア / メモ / 保存
                                           │
                                           ▼ 成功
                                 履歴タブ + シート解除（presentedRecordingRoute = nil）
```

## 関連コード

- `Sources/Presentation/Songs/SongsRootView.swift` — `NavigationStack`（ルート）+ `.sheet(item:)`。記録は push しない
- `Sources/Presentation/Songs/SongsRecordingRoute.swift` — ルート列挙（`Identifiable`）
- `Sources/Presentation/Recording/Sheet/RecordingSheetContainerView.swift` — `presentation: .sheet`（選曲タブから開くとき）。履歴タブの編集は **別経路**で `NavigationStack` + `presentation: .navigationStack` のまま
- `Sources/Presentation/Recording/Sheet/RecordingSheetContentView.swift` — 保存成功時の `onSavedMoveToHistory` / `.sheet` 時の `dismiss()`
- `Sources/Presentation/Root/RootView.swift` — `onSavedMoveToHistory` で `selectedTab = .history`

## インテントタブのランキングシート（I-017）

- **タイムマシン**（`TimeMachineRankingSheetView`）と **マイアンセム**（`MyAnthemRankingSheetView`）は、`IntentTabInsightView` 上で **`.sheet(isPresented:)` を2つ**（`showTimeMachineSheet` / `showMyAnthemSheet`）使っている。通常 UI では同時に開かないが、**両方 `true` になり得ると挙動が曖昧になりうる**。必要なら **`enum ActiveRankingSheet` + `.sheet(item:)` 一本化**を検討する（任意・優先度低）。
