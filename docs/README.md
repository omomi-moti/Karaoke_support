# docs の目次

どの文書を見ればよいかの案内。タスクと仕様の変更は [GitHub Issues](https://github.com/omomi-moti/Karaoke_support/issues)、設計の判断は [ADR](adr/README.md) を正とする（[ADR 0010](adr/0010-issues-and-adr-as-source-of-truth.md)）。最上位のルールは [憲法](../.specify/memory/constitution.md)。

## まず読むもの

| 文書 | 内容 | 正 |
|---|---|---|
| [product_overview.md](product_overview.md) | 何を作っているか・なぜ作るか | |
| [architecture.md](architecture.md) | レイヤー構成（MVVM + Repository）と保存フロー | |
| [adr/](adr/README.md) | 技術判断の記録（ADR）。1 件 1 ファイルで、何を比べてなぜ選んだか | 設計判断の正 |
| [GitHub Issues](https://github.com/omomi-moti/Karaoke_support/issues) | タスクと仕様の変更 | タスク・仕様の正 |

## 設計

| 文書 | 内容 |
|---|---|
| [v1_navigation_songs_recording.md](v1_navigation_songs_recording.md) | 記録シートとタブのナビゲーション |
| [design/color_tokens_v1.md](design/color_tokens_v1.md) | カラートークン（Color Set）の一覧と使い分け |
| [design/track_matching.md](design/track_matching.md) | 曲名の一致・候補の並べ方 |
| [basic_design.md](basic_design.md) | 基本設計書（2026-03 作成） |
| [detailed_design.md](detailed_design.md) | 詳細設計書（データモデル・シーケンス・Spotify API） |

## 仕様・計画（作成時点の資料）

| 文書 | 内容 |
|---|---|
| [raw_spec.md](raw_spec.md) | 最初の要件（v4.1） |
| [development_process.md](development_process.md) | Spec 駆動の進め方と V1 ／ V2 の切り分け |

## 記録

| 文書 | 内容 |
|---|---|
| [manual_qa_I008_I009_record_save.md](manual_qa_I008_I009_record_save.md) | 記録の保存の手動 QA 手順 |
| [cross_check_report.md](cross_check_report.md) | 2026-03-12 時点の仕様書の食い違いの点検結果（作成時点のまま） |
| [screenshots/](screenshots/) | 画面のスクリーンショット |

## アーカイブ（更新していない）

コード中の `I-0xx` 番号の意味を調べるために残している。今のタスクや仕様の確認には使わない。

| 文書 | 内容 |
|---|---|
| [archive/v1_issues.md](archive/v1_issues.md) | V1 の Issue（I-001〜I-019）とタスク、V1 完了判定 |
| [archive/issues.md](archive/issues.md) | 全フェーズの Issue 一覧 |
| [archive/issues_with_tasks.md](archive/issues_with_tasks.md) | 全フェーズの Issue のタスク分解 |

## 書き足すとき

- 設計の判断を決めた・変えたときは [adr/](adr/README.md) に ADR を 1 ファイル足し、一覧に 1 行足す（承認済みの本文は書き換えない）
- タスクや仕様の変更は [GitHub Issues](https://github.com/omomi-moti/Karaoke_support/issues) に書く
