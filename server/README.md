# server

からログの記録をバックアップする API サーバー（Go）。設計は [docs/backend_design.md](../docs/backend_design.md)、判断は [ADR 0048](../docs/adr/0048-introduce-go-server.md)・[0049](../docs/adr/0049-account-and-full-backup.md)・[0050](../docs/adr/0050-postgres-on-neon.md)・[0051](../docs/adr/0051-public-cloud-run-with-caps.md)・[0054](../docs/adr/0054-sign-in-and-server-tokens.md)。

コマンドは、とくに書いていなければ `server/` の中で打つ。

## 要るもの

- Go 1.27
- Docker Desktop（手元の Postgres を動かす・イメージを作る）
- goose v3.29.0（マイグレーション）
- Google Cloud CLI（staging へのデプロイだけ。`brew install --cask gcloud-cli`）

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

2. DB の URL とアプリのバンドル ID を入れる。値はそのターミナルのタブの中だけで有効

   ```bash
   export DATABASE_URL='postgres://karaoke:karaoke@localhost:5432/karaoke?sslmode=disable'
   export APPLE_BUNDLE_ID=com.omomimoti.hitokaralog
   ```

3. マイグレーションを流す

   ```bash
   goose -dir migrations postgres "$DATABASE_URL" up
   ```

4. サーバーを起動する

   ```bash
   go run ./cmd/api
   ```

5. 別のタブで確かめる。DB につながれば `200`、つながらなければ `503`。トークンなしで `/v1/me` を呼ぶと `401`

   ```bash
   curl -i localhost:8080/health
   curl -i localhost:8080/v1/me
   ```

止めるときは、サーバーを `Ctrl + C`、Postgres を `docker compose stop`。`docker compose down -v` はデータも消す。

手元の Postgres は `127.0.0.1` でだけ待ち受ける。パスワードは手元専用で、リポジトリに書いてある。

### Docker のイメージで動かす

staging に出すのと同じイメージを手元で確かめる。Postgres は上の手順 1 で起動しておく。コンテナからは、compose のネットワーク `server_default` の中の `db` という名前で Postgres に届く

```bash
docker build -t karaoke-api .
docker run --rm -p 8080:8080 --network server_default -e DATABASE_URL='postgres://karaoke:karaoke@db:5432/karaoke?sslmode=disable' -e APPLE_BUNDLE_ID=com.omomimoti.hitokaralog karaoke-api
```

## テスト

```bash
go test ./...
```

DB を使わないテスト（ハンドラー・service・Apple のトークンの検証）は、偽物に差し替えて確かめる。

store の SQL のテストと、サインインからログアウトまでを本物の DB で通すテストは、手元の Postgres の URL を `TEST_DATABASE_URL` で渡したときだけ流れる。ないとき・localhost 以外を指すとき・つながらないときは、理由を出して飛ばす。`DATABASE_URL` は使わない（staging の値がシェルに残っていても、テストが staging を書き換えないようにするため）

```bash
docker compose up -d
export TEST_DATABASE_URL='postgres://karaoke:karaoke@localhost:5432/karaoke?sslmode=disable'
goose -dir migrations postgres "$TEST_DATABASE_URL" up
go test -count=1 ./...
```

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
| `APPLE_BUNDLE_ID` | アプリのバンドル ID。Apple のトークンの宛先がこれと一致するかを見る。秘密ではない | なし（なければ起動しない） |

秘密の値を `server/.env` に書くときは、コミットされない（`server/.gitignore`）。staging の値はリポジトリにも打ったコマンドの記録にも残さず、Secret Manager に置く。

## staging へのデプロイ

決めたことは [ADR 0051](../docs/adr/0051-public-cloud-run-with-caps.md)。手でデプロイし、デプロイの前にマイグレーションを手で流す。

### できているもの

| もの | 名前 |
|---|---|
| GCP のプロジェクト | `karaoke-staging-513712`（地域は `asia-northeast1`） |
| イメージの置き場（Artifact Registry） | `karaoke` |
| Cloud Run のサービス | `karaoke-api-staging`（インスタンスの上限 1、誰でも呼べる） |
| サービスアカウント | `karaoke-api-staging`（`database-url-staging` を読む権限だけ） |
| DB（Neon） | `staging` ブランチ（シンガポール） |
| 秘密（Secret Manager） | `database-url-staging`（Neon の `staging` ブランチの URL） |
| 秘密ではない環境変数 | `APPLE_BUNDLE_ID`（`com.omomimoti.hitokaralog`） |
| お金の守り | 予算のアラート（月 500 円）と、Cloud Run の支出の上限（月 300 円）。GCP の画面の「お支払い → 予算とアラート」 |

### 初めての Mac で 1 回だけ

```bash
gcloud auth login
gcloud config set project karaoke-staging-513712
gcloud auth configure-docker asia-northeast1-docker.pkg.dev
```

### デプロイの手順

先にコミットしておく。イメージのタグはコミットの ID なので、コミットしていない変更が入ると、タグと中身が合わなくなる。

1. staging にマイグレーションを流す。DB の URL は Secret Manager から読み、goose にだけ渡す。画面にも打ったコマンドの記録にも残らない

   ```bash
   GOOSE_DRIVER=postgres GOOSE_DBSTRING="$(gcloud secrets versions access latest --secret=database-url-staging)" goose -dir migrations status
   GOOSE_DRIVER=postgres GOOSE_DBSTRING="$(gcloud secrets versions access latest --secret=database-url-staging)" goose -dir migrations up
   ```

2. イメージを作って送る。Cloud Run は amd64 で動くので、ARM の Mac では `--platform` を付ける

   ```bash
   TAG=$(git rev-parse --short HEAD)
   docker buildx build --platform linux/amd64 -t asia-northeast1-docker.pkg.dev/karaoke-staging-513712/karaoke/api:$TAG --push .
   ```

3. デプロイする。2 回目からも同じオプションを付ける

   ```bash
   gcloud run deploy karaoke-api-staging \
     --image asia-northeast1-docker.pkg.dev/karaoke-staging-513712/karaoke/api:$TAG \
     --region asia-northeast1 \
     --service-account karaoke-api-staging@karaoke-staging-513712.iam.gserviceaccount.com \
     --set-secrets DATABASE_URL=database-url-staging:latest \
     --set-env-vars APPLE_BUNDLE_ID=com.omomimoti.hitokaralog \
     --max-instances 1 \
     --allow-unauthenticated
   ```

4. 確かめる。`200` と `{"status":"ok"}` が返ればよい。止まっていた後の最初の 1 回は、Cloud Run と Neon が起きるので数秒かかる

   ```bash
   curl -i "$(gcloud run services describe karaoke-api-staging --region asia-northeast1 --format='value(status.url)')/health"
   ```

前のイメージに戻すときは、3 の `--image` に前のタグを入れてデプロイする。

### DB の URL を替える

Neon でパスワードを変えたときなど。Neon の画面で `staging` ブランチの「Connect」を開き、Connection pooling をオフにして（ホスト名に `-pooler` がない形）コピーしてから、すぐに打つ。チャットやターミナルに URL を貼らない

```bash
pbpaste | gcloud secrets versions add database-url-staging --data-file=-
pbcopy < /dev/null
```

Cloud Run は新しいインスタンスから新しい版を読む。すぐに切り替えたいときは、3 のデプロイをもう一度流す。古い版は番号を確かめてから消す（戻せない）

```bash
gcloud secrets versions list database-url-staging
gcloud secrets versions destroy 古い版の番号 --secret=database-url-staging
```

### 古いイメージを消す

イメージの置き場は無料の容量を超えると課金される。動いているタグは消さない

```bash
gcloud artifacts docker images list asia-northeast1-docker.pkg.dev/karaoke-staging-513712/karaoke --include-tags
gcloud artifacts docker images delete asia-northeast1-docker.pkg.dev/karaoke-staging-513712/karaoke/api:消すタグ --delete-tags
```
