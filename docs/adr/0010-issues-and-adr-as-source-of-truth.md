# 0010. タスクは GitHub Issues、判断は ADR を正とし、旧 Issue 一覧は archive に残す

- 2026-10-14 ／ 承認
- 背景：2026-03 に仕様書が 5 つ以上（raw_spec → spec → basic_design → detailed_design → issues）あり、Spotify メタデータのキャッシュを「UserDefaults」とするものと「インメモリ 24h」とするものが混在した。`cross_check_report.md` で食い違いを洗い出してそろえ、V1 の範囲は `v1_issues.md` を正とした。その後タスクの管理は GitHub Issues（#87 以降）に移り、`v1_issues.md` は更新されずに実装と食い違うようになった（点数が Slider で必須、など）。CLAUDE.md も毎回これを読み込んでいた

## 比較した案
- A. `v1_issues.md` を正のまま、GitHub Issues と並べて更新し続ける
- B. `v1_issues.md`・`issues.md`・`issues_with_tasks.md` を削除する
- C. 正として扱うのをやめ、`docs/archive/` に移して残す

## トレードオフ
- A は 1 か所で V1 の全体を見られるが、Issues とファイルの二重管理になり、1 人では食い違いを直し続けられない
- B はすっきりするが、コード中のコメントにある `I-017`・`I-014-C` などの番号（60 か所）が何を指すか分からなくなり、ここにしかない経緯（I-019 の設計メモ、I-014 のレビューのリスク）も消える
- C は古い内容が残るが、archive と明示すれば正と取り違えない

## 選んだ理由
- C。役割をこう分ける
  - タスクと仕様の変更：[GitHub Issues](https://github.com/omomi-moti/Karaoke_support/issues)
  - 設計の判断：ADR（`docs/adr/`）
  - 画面・データの設計：`design/` などの設計文書
- 旧 Issue 一覧は、コード中の `I-0xx` 番号の意味を引くために残す。各ファイルの冒頭に archive であることを書く
- CLAUDE.md からの読み込み（`@docs/v1_issues.md`）を外し、毎回の会話で古い内容を読ませない

## 見直す条件
- コード中の `I-0xx` 番号を GitHub Issue の番号に置き換えるなどして、archive を参照しなくなったら削除する

関連：[archive/v1_issues.md](../archive/v1_issues.md)、[cross_check_report.md](../archive/cross_check_report.md)
