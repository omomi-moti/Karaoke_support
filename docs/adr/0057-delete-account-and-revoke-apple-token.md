# 0057. アカウントの削除は、本人の Apple ID を確かめ、Apple のトークンを取り消せたときだけ行う

- 2026-11-12 ／ 承認
- 背景：ADR 0053 の 3-A で、アカウントを消すときにもう一度 Sign in with Apple を出し、そのとき来た認可コードで Apple のトークンを取り消すと決めた。その実装で、どの Apple ID のトークンを取り消すのか、Apple の側で失敗したらどうするのか、Apple の鍵をどこに置くのかを決める（#157）

Apple の文書（Sign in with Apple REST API）で確かめたこと：

- 認可コードは `POST https://appleid.apple.com/auth/token`（`grant_type=authorization_code`）でトークンに替える。コードは 1 回だけ使え、5 分で切れる。`redirect_uri` は、最初の認可の要求で渡したときだけ要る（iOS のアプリは渡していない）
- 返事の `refresh_token`・`access_token`・`id_token` は、どれも必ず入るとは書かれていない
- 取り消しは `POST https://appleid.apple.com/auth/revoke` に `token` と `token_type_hint`（`refresh_token` か `access_token`）を送る。成功すると 200 で本文はなく、すでに取り消してあっても 200
- どちらも `client_id` と `client_secret` が要る。`client_secret` は、Sign in with Apple の鍵（.p8）で `ES256` で署名した JWT（`iss` はチームの ID、`sub` は `client_id`、`aud` は `https://appleid.apple.com`、期限は最大 6 か月）
- 失敗は 400 で、`{"error": "invalid_grant"}` のような形

## 比較した案

1. 消す Apple ID が本人のものかの確かめ方
- A. iOS から認可コードと一緒に identity token と nonce も送り、サインインと同じ検証（`appleauth.Verifier`）で `sub` を取り、今のアカウントの `apple_user_id` と比べる
- B. 認可コードをトークンに替えた返事の `id_token` から `sub` を取って比べる
- C. 比べない

2. Apple の側で失敗したとき（届かない・トークンに替えられない・取り消せない）
- A. アカウントを消さずに失敗を返す。もう一度押せばやり直せる
- B. こちらのアカウントは消し、失敗はログにだけ残す

3. `client_secret` の作り方
- A. Apple の鍵（.p8）を Secret Manager に置き、リクエストのたびに短い期限（5 分）で作る
- B. 6 か月の `client_secret` を手元で作り、それを Secret Manager に置く

4. 鍵が設定されていないとき
- A. 起動しない（`DATABASE_URL`・`APPLE_BUNDLE_ID` と同じ）
- B. 起動し、アカウントの削除だけ 500 にする

## トレードオフ

- 1-A は今ある検証を使い回せ、nonce で使い回しも防げる。iOS が送るものが 3 つになる。1-B は送るものが認可コードだけで済むが、文書では `id_token` が必ず入るとは書かれておらず、返事に頼る形になる。1-C は、別の Apple ID で Apple の画面を通ると、こちらのアカウントは消えるのに、本人の Apple ID とこのアプリのつながりが残る
- 2-A は、Apple の障害の間は消せない。代わりに、こちらだけ消えて Apple の側のつながりが残ることがない。2-B は障害の間も消せるが、つながりが残っても本人は気づけず、後から取り消す手段もない（Apple のトークンを持たないため）
- 3-A は、Secret Manager に置くのが Apple の鍵そのものになり、漏れたときの影響は大きいが、期限の切れ目を気にしなくてよい。3-B は置く値が 6 か月で切れるので、半年ごとに作り直す手間があり、忘れると削除が止まる
- 4-A は設定の漏れにデプロイの時点で気づける。代わりに、手元で動かすときも鍵（試し用でよい）が要る。4-B は手元で楽だが、staging に鍵を入れ忘れても気づかず、削除だけが静かに壊れる

## 選んだ理由

- 1 は A。Apple の返事に必ず入るとは限らない値に頼るより、サインインで確かめ済みの検証を使い回す方が確実で、テストもそのまま使える
- 2 は A。Apple の側のエラーで、アカウントがおかしな形で消えるのは防ぐ。消すのは、Apple の側も含めてきれいに消せたときだけにする
- 3 は A。半年ごとの作り直しを覚えておく必要がない。鍵は Secret Manager に置き、サービスアカウントにだけ読ませる
- 4 は A。アカウントを消せることは外部に配る条件なので、鍵がないまま動くより、起動しない方がよい

## 決めたこと

- `DELETE /v1/me` は認証が要る。本文は `{"identityToken": "...", "authorizationCode": "...", "nonce": "..."}`
- 流れ：Bearer で今のアカウントを決める → identity token と nonce を検証して `sub` を取る → 今のアカウントの `apple_user_id` と比べる → 認可コードをトークンに替える → `refresh_token` を取り消す（なければ `access_token`）→ `DELETE FROM users WHERE id = $1`（トークンとバックアップは `ON DELETE CASCADE` で一緒に消える）→ 204
- 返すもの：
  - Bearer のトークンが使えない：401（ミドルウェア）
  - 本文が壊れている・identity token を受け付けない・認可コードが切れている（Apple の `invalid_grant`）：400
  - Apple ID が今のアカウントと違う：403
  - Apple に届かない・そのほかの Apple の失敗・DB の失敗：500。どれもアカウントは消さない
- Apple の鍵は Secret Manager の `apple-signin-key-staging` に置き、`APPLE_SIGNIN_KEY` として渡す。鍵の ID（`APPLE_KEY_ID`）とチームの ID（`APPLE_TEAM_ID`）は秘密ではないので、環境変数で渡す。どれかがなければ起動しない
- `client_id` はバンドル ID（`APPLE_BUNDLE_ID`）を使う。文書には iOS のアプリならバンドル ID だとはっきり書かれていないので、実機で確かめる
- iOS の端末の記録（SwiftData）は消さない。確認の文にそう書く

## 見直す条件

- Apple の障害で、消したいのに消せないと言われたとき（2 を見直す）
- 実機で、バンドル ID を `client_id` にして `invalid_client` になったとき
- Apple の鍵が漏れた・漏れた疑いがあるとき（鍵を取り消して作り直し、3 を見直す）

関連：#157、[0053](0053-beta-testers-and-auto-backup.md)、[0054](0054-sign-in-and-server-tokens.md)
