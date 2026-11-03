# server

からログの記録をバックアップする API サーバー（Go）。設計は [docs/backend_design.md](../docs/backend_design.md)、判断は [ADR 0048](../docs/adr/0048-introduce-go-server.md)・[0049](../docs/adr/0049-account-and-full-backup.md)。

コマンドは、とくに書いていなければ `server/` の中で打つ。

## 要るもの

- Go 1.27
- Docker Desktop（手元の Postgres を動かす）
- goose v3.29.0（マイグレーション）

goose は Mac に直接入れる。`go.mod` の `tool` に入れると、使わない DB のドライバーまで依存に入るため、Postgres のドライバーだけでビルドする。

```bash
go install -tags='no_clickhouse no_libsql no_mssql no_mysql no_sqlite3 no_vertica no_ydb' github.com/pressly/goose/v3/cmd/goose@v3.29.0
```

`goose: command not found` と出たら、`~/go/bin` を PATH に足す。

```bash
echo 'export PATH="$HOME/go/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

## 手元で動かす

1. Postgres を起動する。Docker Desktop が起動している必要がある。データはボリューム `db-data` に残る

   ```bash
   docker compose up -d
   ```

2. DB の URL を入れる。値はそのターミナルのタブの中だけで有効

   ```bash
   export DATABASE_URL='postgres://karaoke:karaoke@localhost:5432/karaoke?sslmode=disable'
   ```

3. マイグレーションを流す

   ```bash
   goose -dir migrations postgres "$DATABASE_URL" up
   ```

4. サーバーを起動する

   ```bash
   go run ./cmd/api
   ```

5. 別のタブで確かめる。DB につながれば `200`、つながらなければ `503`

   ```bash
   curl -i localhost:8080/health
   ```

止めるときは、サーバーを `Ctrl + C`、Postgres を `docker compose stop`。`docker compose down -v` はデータも消す。

手元の Postgres は `127.0.0.1` でだけ待ち受ける。パスワードは手元専用で、リポジトリに書いてある。

## テスト

```bash
go test ./...
```

DB は要らない。ハンドラーは偽物の DB（`Pinger`）で確かめる。

## マイグレーション

- ファイルは `migrations/` に、`00001_create_users.sql` のように 5 桁の連番で置く。中は `-- +goose Up` と `-- +goose Down` に分ける
- 流す前に `status` で、まだ流していないもの（`Pending`）を見る

  ```bash
  goose -dir migrations postgres "$DATABASE_URL" status
  ```

- `up` はまだ流していないものを全部流す。`down` は最後の 1 つだけ戻す
- コミットしたファイルは書き換えない。staging の DB は流し済みの番号を覚えているので、書き換えても流れない。直すときは新しい番号のファイルを足す

## 環境変数

| 名前 | 中身 | 初期値 |
|---|---|---|
| `PORT` | 待ち受けるポート。Cloud Run が渡す | `8080` |
| `DATABASE_URL` | Postgres の URL | なし（なければ起動しない） |

秘密の値を `server/.env` に書くときは、コミットされない（`server/.gitignore`）。staging の値はリポジトリにも打ったコマンドの記録にも残さず、Secret Manager に置く。

## staging へのデプロイ

Issue #146 の手順 5 で書く。
