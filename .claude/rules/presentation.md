---
paths:
  - "Karaoke_support/Karaoke_support/Sources/Presentation/**"
  - "Karaoke_support/Karaoke_support/Sources/App/Environment/**"
  - "Karaoke_support/Karaoke_support/Sources/App/PreviewSupport/**"
---

# View と ViewModel

## View

- **View は描画だけ。** Repository の呼び出し、業務のロジック、非同期の処理を View に書かず、ViewModel に任せる。Container の View は `@Environment` から Repository を読み、`init` で ViewModel を作ってよい（例：`HistoryListContainerView`、`SettingsContainerView`）。
- ここでは Repository の具体的な型（`SwiftData…Repository`）を参照しない。環境から受け取る `…RepositoryProtocol` を使う。編集のたびにフックが確かめる。
- プロパティラッパー：`@State` は View の中の一時的な状態と、ViewModel を持つために使う。`@Binding` は親からの双方向の値。`@Environment` は Repository とアプリ全体の値。`@Query`、`@StateObject`、`@ObservedObject` は使わない。
- 名前：画面は `{機能}View` / `{役割}View`、使い回す部品は `{用途}{種類}`（`TrackRowView`、`IntentBadgeView`）。
- プレビューできる View には必ず `#Preview` を付ける。記録シートを出すプレビューには `NetworkMonitor(startsMonitoring: false)` を注入する。

## ViewModel

- **古い結果で上書きしない**：読み込み中に次の読み込みが始まりうる ViewModel は `loadGeneration` を持ち、終わった読み込みがまだ最新のときだけ結果を書く。`do`・`catch`・`defer` のどれでも同じ。`Task.cancel()` だけでは足りない。
- **履歴のスナップショット**：`HistoryViewModel` は読んだ直後に `SingingSession` を値型の `HistorySessionRowDisplayItem` に写す。削除はまずスナップショットから消し、失敗したら戻す。1 ページ 20 行、下から 5 行で次を読み、最大 500 行。
- 保存のあとや次のシートを出すのは `RootView`（`handleSaved`、`present()`）を通す。タブの `NavigationStack` の中からシートを出さない（ADR 0025・0032）。

## このフォルダを変えたら見直す文書

- `docs/v1_navigation_songs_recording.md`（シートとタブの動き）
- `docs/architecture.md` の「ユーザーフロー」の図
- 見た目が変わったら `README.md` のスクリーンショット（`docs/screenshots/`）
