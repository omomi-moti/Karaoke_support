# 0022. 記録の編集も `RootView` のシートで開き、＋ボタンを隠す仕組みをなくす

- 2026-10-23 ／ 承認
- 背景：[0020](0020-hide-add-button-on-edit-screen.md) では、編集画面を履歴タブに push し、画面から PreferenceKey で＋ボタンを隠していた。記録の読み込み中・失敗の画面では隠れず、戻るときは＋が出ていく編集画面の上に先に出ていた。合図が `NavigationStack` の外まで届くことにも頼っていた。編集の push は比べて選んだものではなく、2026-03-25 に記録画面をシートへ変えたとき、編集だけが push のまま残っていた

## 比較した案
- A. push のまま、隠す合図を履歴タブの積み方（`[HistoryRoute]` の一番上が編集か）から出す
- B. 編集も、追加と同じ `RootView` のシートで開く

## トレードオフ
- A は左端のスワイプで戻れる。ただ、隠す仕組みが残り、戻るとき＋が先に出る件も残る
- B は＋がシートの下に隠れるので、隠す仕組みがいらない。追加と同じ出方になり、HIG（Sheets・Modality：範囲のはっきりした 1 つの作業はシート）とも合う。X・Slack も＋から開く画面はモーダルだった。代わりに左端のスワイプでは戻れず、下スワイプで閉じると編集中の内容が確認なしで消える（追加と同じ）

## 選んだ理由
- B。＋ボタンの要件「記録・編集の画面の上に＋が見えない・押せない」を、仕組みなしで満たせる
- 履歴のスワイプからは Environment の `navigateToEditRecording` で `RootView` のシートを開く。`RecordingContentPresentation`、`AddRecordingButtonHiddenPreferenceKey`、`HistoryRoute.editSession` は消した
- 実機で、数字キーボードを出したまま「更新する」を押しても、戻ったあとの＋はいつもの位置にあることを確かめた（録画 2026-10-23）

## 見直す条件
- 下スワイプで閉じたときに入力が消える件を直すとき（確認を出す、下書きを残すなど）
- 編集の画面が 1 枚に収まらなくなったとき

関連：[0008](0008-single-recording-sheet-on-root.md)、[0020](0020-hide-add-button-on-edit-screen.md)（置き換え）、[0021](0021-single-add-button-measured-from-tab-safe-area.md)
