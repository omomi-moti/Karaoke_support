---
paths:
  - "server/**"
---

# サーバー（Go）

全体像は `docs/backend_design.md`、動かし方とデプロイは `server/README.md` を見る。

## 分け方

- `internal/` の下は機能ごとのパッケージにし、中を handler・service・store の 3 段に分ける。handler は入出力・認証・大きさの上限、service はルール、store は SQL だけを持つ（`docs/backend_design.md` の「責任の分け方」）。
- インターフェースは使う側のパッケージに置き、使うメソッドだけを書く（例：`httpapi.Pinger`）。テストでは偽物に差し替える。
- `cmd/api/main.go` は設定を読み、依存を組み立てるだけにする。
- 標準の `net/http` と `pgx` を使い、フレームワークや ORM は入れない（ADR 0048）。依存を足すときは、先に理由を書いて相談する。

## データとログ

- 記録を読む・書く SQL は、必ず認証で分かった自分の `user_id` で絞る。本文や URL に入ってきた ID で他人の行に届かないようにする。
- メモは受け取らず、保存しない（憲法、ADR 0049）。Apple Music の曲名などのメタデータも持たない。
- ログとエラーの返事に、記録の中身（曲名・点数・気分）、トークン、`Authorization` ヘッダー、DB の URL を出さない（NFR-3）。エラーの返事は決まった短い文にし、詳しいことはログにだけ出す。
- 本文を読む API は `http.MaxBytesReader` で大きさを抑える（NFR-5）。その API を足すときに、`http.Server` に `ReadTimeout`・`WriteTimeout`・`IdleTimeout` も付ける。

## マイグレーション

- `migrations/` に 5 桁の連番で足す。コミットしたファイルは書き換えず、直すときは新しい番号を足す。

## 秘密

- 秘密の値（DB の URL、鍵、トークン）をコード・テスト・文書・コミットに書かない。例外は手元の `compose.yaml` の Postgres のパスワードだけ。staging の値は Secret Manager に置く。
- 秘密の値を読むコマンド（`gcloud secrets versions access` など）は、形を確かめるだけでも、本人の了承をもらってから打つ。

## 変えたら流すもの

`server/` の中で打つ。

```bash
gofmt -l .
go vet ./...
go test ./...
```

## このフォルダを変えたら見直す文書

- `server/README.md`（手順・環境変数・staging にできているもの）
- `docs/backend_design.md`（API・フォルダ・責任の分け方・Issue の進み具合）
- 判断をしたら `docs/adr/`
