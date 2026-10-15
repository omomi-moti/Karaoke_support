# 0018. 履歴の行は NavigationLink ではなく Button で曲詳細を開く

- 2026-10-15 ／ 承認
- 背景：履歴の行を `List` の中の `NavigationLink` で包んでいたため、iOS が行の右端に「›」を自動で付け、カードの外に矢印が見えていた

## 比較した案
- A. `NavigationLink` のまま、矢印を受け入れる
- B. 透明な `NavigationLink` を行に重ね、矢印だけ見えなくする
- C. `Button` にし、タップで `navigationPath.append(...)` する

## トレードオフ
- A は標準の作りのままだが、カードの外に矢印が出て、カードの幅も矢印の分だけ狭くなる
- B は矢印が消えるが、見えない部品を置くことになり、タップの領域や VoiceOver の読み上げが重なりうる
- C は矢印が出ず、カードが横幅いっぱいになる。画面の移り方を自分で書くので、`NavigationLink` に任せていた部分（遷移先の型を値で渡すことなど）を `HistoryRoute` で扱う

## 選んだ理由
- C。編集のスワイプがすでに `navigationPath.append(HistoryRoute.editSession(...))` で画面を移っているので、行のタップも同じ書き方にそろう

## 見直す条件
- 行からの遷移先が増え、値で遷移先を決める `NavigationLink` のほうが扱いやすくなったとき（記録を 1 件ずつ見る画面、#104 など）
