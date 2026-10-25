# docs の目次

どの文書を見ればよいかの案内。タスクと仕様の変更は [GitHub Issues](https://github.com/omomi-moti/Karaoke_support/issues)、設計の判断は [ADR](adr/README.md) を正とする（[ADR 0010](adr/0010-issues-and-adr-as-source-of-truth.md)）。最上位のルールは [憲法](constitution.md)。

## まず読むもの

| 文書 | 内容 | 正 |
|---|---|---|
| [product_overview.md](product_overview.md) | 何を作っているか・なぜ作るか | |
| [architecture.md](architecture.md) | レイヤー構成（MVVM + Repository）と保存フロー | |
| [development_process.md](development_process.md) | 進め方（Issue・ADR・スプリント）と AI の使い方、V1 ／ V2 の切り分け | |
| [adr/](adr/README.md) | 技術判断の記録（ADR）。1 件 1 ファイルで、何を比べてなぜ選んだか | 設計判断の正 |
| [GitHub Issues](https://github.com/omomi-moti/Karaoke_support/issues) | タスクと仕様の変更 | タスク・仕様の正 |

## 設計

| 文書 | 内容 |
|---|---|
| [v1_navigation_songs_recording.md](v1_navigation_songs_recording.md) | 記録シートとタブのナビゲーション |
| [design/color_tokens_v1.md](design/color_tokens_v1.md) | カラートークン（Color Set）の一覧と使い分け |
| [design/track_matching.md](design/track_matching.md) | 曲名の一致・候補の並べ方 |

## 記録

| 文書 | 内容 |
|---|---|
| [screenshots/](screenshots/) | 画面のスクリーンショット（README で使う） |

## アーカイブ（更新していない）

作ったときのまま止まっている文書。経緯や、コード中の `I-0xx` 番号の意味を調べるために残している。今のタスクや仕様の確認には使わない。

| 文書 | 内容 |
|---|---|
| [archive/raw_spec.md](archive/raw_spec.md) | 最初の要件（v4.1） |
| [archive/basic_design.md](archive/basic_design.md) | 基本設計書（2026-03 作成。最低対応 OS など、今の実装と違う記述がある） |
| [archive/detailed_design.md](archive/detailed_design.md) | 詳細設計書（2026-03 作成。データモデル・シーケンス・クラス図は今の実装と違う。V2 の Spotify Web API の仕様はここにしかないので、V2 を始めるときに取り出す） |
| [archive/cross_check_report.md](archive/cross_check_report.md) | 2026-03-12 時点の仕様書の食い違いの点検結果 |
| [archive/manual_qa_I008_I009_record_save.md](archive/manual_qa_I008_I009_record_save.md) | V1 の記録の保存の手動 QA 手順（今の画面とは違う） |
| [archive/v1_issues.md](archive/v1_issues.md) | V1 の Issue（I-001〜I-019）とタスク、V1 完了判定 |
| [archive/issues.md](archive/issues.md) | 全フェーズの Issue 一覧 |
| [archive/issues_with_tasks.md](archive/issues_with_tasks.md) | 全フェーズの Issue のタスク分解 |
| [archive/log/](archive/log/) | 2026-03〜07 の実装ログ（`I-0xx` ごと） |

## 書き足すとき

- 設計の判断を決めた・変えたときは [adr/](adr/README.md) に ADR を 1 ファイル足し、一覧に 1 行足す（承認済みの本文は書き換えない）
- タスクや仕様の変更は [GitHub Issues](https://github.com/omomi-moti/Karaoke_support/issues) に書く
