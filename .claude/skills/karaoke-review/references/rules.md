# ルール詳細

各ルールは**不変条件**として書いてある。満たす実装手段は問わない。
手段を固定すると、正当なリファクタをレビューがブロックしてしまうため。

必要な節だけ読む。全部読む必要はない。

- [Spotify メタデータの永続化](#spotify-メタデータの永続化)
- [編集の握り潰し](#編集の握り潰し)
- [古い非同期結果の上書き](#古い非同期結果の上書き)
- [二重保存](#二重保存)
- [Repository を経由しない DB 書き込み](#repository-を経由しない-db-書き込み)
- [Presentation への具体 Repository 型の漏れ](#presentation-への具体-repository-型の漏れ)

サーバー（`server/`）

- [他人の記録に届く SQL](#他人の記録に届く-sql)
- [メモがサーバーに渡る](#メモがサーバーに渡る)
- [秘密がリポジトリに入る](#秘密がリポジトリに入る)
- [流し済みのマイグレーションの書き換え](#流し済みのマイグレーションの書き換え)
- [ログやエラーの返事に記録の中身や秘密が出る](#ログやエラーの返事に記録の中身や秘密が出る)
- [サーバーのトークンの扱い](#サーバーのトークンの扱い)
- [Apple のトークンの検証の抜け](#apple-のトークンの検証の抜け)

---

## Spotify メタデータの永続化

### 不変条件

Spotify 由来の**曲名・アーティスト名・アートワーク・プレビュー URL** を、
SwiftData / UserDefaults / ファイル / Keychain のいずれにも書かない。

永続化してよいのは以下だけ:

- `spotifyTrackId` — 識別子であってメタデータではない
- `userEnteredName` — ユーザーが自分で入力した文字列

### 破れたときの症状

Spotify Developer Terms 違反。最悪の場合 API キー失効、アプリ配信停止。
**コードを直せば済む問題ではない**ため、他のどのルールより優先して報告する。

### なぜこの制約があるか

`docs/constitution.md` の Core Principle I（外部の曲データの扱い）。
外部の曲データは今は使っていないが、使うときは識別子だけを永続化し、メタデータは永続化しない。
キャッシュなどの具体的なやり方は、使うと決めたときに ADR で決める。

### 検出手順

1. `Track` / `SingingSession` など `@Model` 型へのプロパティ追加を確認する
2. `grep -rn 'UserDefaults' Sources` — 今は 0 件が正常
3. API 応答の型から `@Model` のプロパティへ代入している箇所を探す
4. ファイル書き込み（`FileManager`, `Data.write`, `Codable` の永続化）を探す

### 現状

`Data/Spotify/` と `Data/Cache/` は `.gitkeep` のみで空。
今は検出対象が存在しない。**外部の曲データ（Spotify など）を使い始めた時点で発火する**ルール。

### 誤検知しやすいケース

- `spotifyTrackId` の保存は**正しい**。識別子は永続化してよい
- Spotify ID を短縮して表示用文字列にする処理（`TrackDisplayTitle`）も問題ない。
  表示のために加工しているだけで、メタデータを保存していない
- インメモリのキャッシュは永続化ではない。
  「キャッシュしている」こと自体を違反としない。見るのは永続化先があるかどうか

---

## 編集の握り潰し

**このプロジェクトで最も検出価値が高いルール。** 無言で失敗し、テストもすり抜けるため。

### 不変条件

既存の `SingingSession` を変更する経路は `updateRecordingSession` のみ。
`saveNewRecordingSession` に**既に DB に存在する id を渡さない**。

### 破れたときの症状

**編集内容が保存されていないのに、保存成功として履歴タブに戻る。**
エラーも例外も出ない。ユーザーは保存できたと思って画面を閉じる。

### なぜ起きるか

`saveNewRecordingSession` は二重送信対策（I-011）のため、先頭で `exists(uuid:)` を見る。
既存 id なら **insert も `singCount` 加算も、プロパティの上書きも行わずに正常終了する**。

「同一キーの再送は無視する」がこのメソッドの仕様であって、バグではない。
呼び分けを誤ると、この仕様に静かに飲み込まれる。

さらに厄介なのは、ViewModel のテストがモック Repository を使っている場合、
モックも同様に成功を返すため**テストが通ってしまう**点にある。
コンパイラもテストも守ってくれないので、レビューで見るしかない。

### 検出手順

1. `grep -rn 'saveNewRecordingSession' --include='*.swift' Sources`
2. 各呼び出しについて、渡している `SingingSession` の `id` の出どころを遡る
3. その id が「新規採番された UUID」か「既存 session 由来」かを判定する

判定できないときは、その id を組み立てている箇所まで読む。推測で報告しない。

### 正例

`Sources/Presentation/Recording/Sheet/RecordingSheetViewModel.swift` の `save()`。
編集 id の有無で経路を分けている。

```swift
if let editId = editingSessionId {
    let session = SingingSession(id: editId, track: track, ...)
    try await sessionRepository.updateRecordingSession(session)
    return Self.savedRecording(session, isNewRecording: false)
}
// 以降は新規採番して saveNewRecordingSession へ
```

### 違反例

```swift
// 編集も新規も同じ経路に流している
let session = SingingSession(id: editingSessionId ?? UUID(), track: track, ...)
try await sessionRepository.saveNewRecordingSession(session)
// 編集時は exists が true になり、何も起きずに成功が返る
```

### 誤検知しやすいケース

**保存失敗後の再試行で同じ UUID を使い回すのは正しい実装。**
`RecordingSheetViewModel` の `pendingSessionIdForSave` がこれにあたる。
冪等キーの本来の用途であり、二重保存を防いでいる。

つまり「同じ id を 2 回渡している」だけでは違反にならない。
判定基準は **「その id の session が、その時点で DB に既に存在しうるか」**。

- 1 回目が失敗して DB に入っていない → 同じ id で再送するのは正しい
- 1 回目が成功して DB に入っている → 同じ id を `saveNew` に渡すのは違反

テストコードが意図的に同一 id を再送しているケース
（`I011SessionIdempotencyTests`）も対象外。

### 関連する既知の境界仕様

保存に失敗した後、**入力内容を変えてから**再試行すると、
`pendingSessionIdForSave` により同じ id で送られる。
1 回目が実際には DB に入っていた場合、変更が反映されないまま成功に見える。

V1 では「失敗後は同じ内容でやり直す」運用で回避している（`docs/archive/v1_issues.md` I-011）。
この経路のリトライ挙動に触れる変更があれば、境界仕様を壊していないか確認する。

---

## 古い非同期結果の上書き

### 不変条件

`await` から戻った後、**取得結果を状態に書き込む前に**、その処理がまだ最新かを判定する。

判定手段は問わない。`Task.isCancelled` でも `.task(id:)` でも世代カウンタでもよい。
重要なのは「判定があること」であって、どう実装したかではない。

### 破れたときの症状

**フィルタを切り替えた直後に、切り替え前の一覧が一瞬表示される。**
または**削除した行が復活する**。

再現条件が通信速度やタップ間隔に依存するため、
ユーザーからは「たまにバグる」としか報告されず、原因特定が難しい。

### なぜ `cancel()` だけでは足りないか

`Task.cancel()` はフラグを立てるだけで、実行中の `await` を即座に止めない。
中断していた処理は**再開してから**キャンセルに気づく。
再開後に判定を入れなければ、古い結果がそのまま状態を上書きする。

### 判定が必要な箇所（見落としやすい順）

1. **`await` の直後、状態への代入前**

2. **`defer` の中** — 最も見落とされる

   古い処理の `defer { isLoading = false }` が、
   新しい処理が立てた `isLoading = true` を消してしまう。
   結果、読み込み中なのにスピナーが消える。

   ```swift
   defer { if !Task.isCancelled { isLoading = false } }
   ```

3. **`catch` 節での代入**

   古い失敗が、新しい成功の後にエラーメッセージを表示する。

### 検出手順

1. 変更に `await` を含む ViewModel メソッドがあるか確認する
2. その `await` の後で `self` の `var` に代入しているか確認する
3. 代入の前に判定があるか確認する。`defer` と `catch` も同じ目で見る

### 誤検知しやすいケース

- **判定が二重・三重になっているのは違反ではない。** 冗長なだけ。
  簡素化の提案として出してよいが、**バグとしては報告しない**
- `await` の後に**状態を書かない**メソッド（取得だけして呼び出し元に返す）は対象外
- View 側で `.task(id:)` を使っている場合、フィルタ変更時のキャンセルは
  SwiftUI が行う。ViewModel 側に世代カウンタが無いことを違反としない

### 設計メモ

`.task(id:)` の管轄外から始まる非同期（例: スワイプ削除、保存ボタン）は、
SwiftUI のキャンセルが効かないため独自の判定が要る。

ただし、そもそも**削除後に一覧を再取得しない**設計にすれば競合自体が消える。
楽観的に行を除いた時点で表示は正しいため、再取得は不要なことが多い。
再取得を伴う削除フローを見たら、その必要性を問う指摘を出してよい
（再取得が 1 ページ目だけをやり直す実装だと、ページング位置も失われる）。

---

## 二重保存

### 不変条件

保存ボタンの連打で、`SingingSession` が 2 件保存されない。

これも手段は問わないが、**UI 側のガードだけでは不十分**である点に注意する。

### 破れたときの症状

履歴に同じ記録が 2 件並ぶ。`Track.singCount` も 2 加算され、
ランキングの集計が実際より多く出る。ユーザーが手で消すまで残り続ける。

### なぜ二層必要か

- **UI 側のガードだけ**では、1 回目の `await` 中に 2 回目が入り込む隙間が残る。
  非同期の中断点があるため、フラグを立てるタイミングによっては競合する
- **データ層の冪等だけ**では、連打中にボタンが押せたままになり、
  スピナーも出ないため UX が壊れる。保存できたかどうかユーザーに分からない

どちらか片方では要件を満たせない。

### 検出手順

1. 保存を開始するメソッドの冒頭に、実行中を弾くガードがあるか
2. Repository 側に冪等キー（クライアント生成 UUID）による重複チェックがあるか
3. 保存中にボタンが非活性になり、進行状態が表示されるか

### 正例

`RecordingSheetViewModel.save()` の冒頭。

```swift
guard !isSaving else { return nil }
guard validate() else { return nil }
isSaving = true
defer { isSaving = false }
```

これに加えて、Repository 側が `exists(uuid:)` で冪等性を担保している。

### 誤検知しやすいケース

- `updateRecordingSession`（編集）は冪等チェックの対象外でよい。
  上書きなので 2 回実行しても結果が同じになる
- 削除も同様に、同じ id を 2 回消しても結果は変わらない

---

## Repository を経由しない DB 書き込み

### 不変条件

`modelContext.insert` / `.delete` / `.save` は、
`Sources/Data/SwiftData/` と `Sources/App/KaraokeSupportApp.swift` の外に出ない。

### 破れたときの症状

`Track.singCount` の整合が崩れる。
セッションだけが増減して回数が追随せず、ランキングの数字が実データと合わなくなる。

`singCount` の更新は Repository 側でしか行われないため、
View から直接 insert すると、この更新が丸ごと抜ける。

副次的に、その書き込み経路はユニットテストでモックに差し替えられなくなる。

### 検出手順

```bash
grep -rn 'modelContext' Sources/Presentation Sources/Domain
```

0 件が正常。

### 誤検知しやすいケース

- `App/KaraokeSupportApp.swift` が `ModelContainer` を構築し、
  そのコンテキストを Repository に渡すのは正しい配線
- `@Environment(\.modelContext)` を App 層で読むこと自体は違反ではない。
  見るのは Presentation / Domain に書き込みが漏れていないか

---

## Presentation への具体 Repository 型の漏れ

優先度は低い。現状 0 件のため、回帰を検出するためのルール。

### 不変条件

`SwiftDataSessionRepository` などの具体型名が `Sources/Presentation/` に現れない。
ViewModel は `any SessionRepositoryProtocol` を `init` で受け取る。

### 破れたときの症状

その ViewModel のユニットテストが書けなくなる。
テストが実 DB に依存し、`ModelContainer` の準備なしには動かなくなる。

### 検出手順

```bash
grep -rn 'SwiftData[A-Z][A-Za-z]*Repository' Sources/Presentation
```

0 件が正常。

### 誤検知しやすいケース

- `Sources/App/PreviewSupport/` のプレビュー用モックは Presentation ではないので対象外
- テストコード内での具体型の使用も対象外

### 注意

単一ターゲットのため、`import` によるモジュール境界の強制は存在しない。
`Data/` と `Presentation/` は実質ただのフォルダであり、これは規律の問題である。

このチェックは決定論的なので、将来はビルドフェーズのスクリプトに移すほうが確実で速い。
レビューで見るのは、文脈込みで判断したい場合に限る。

---

## 他人の記録に届く SQL

### 不変条件

記録・バックアップ・トークンなど、利用者ごとの行を読む・書く・消す SQL は、
認証で分かった自分の `user_id` で必ず絞る。
`user_id` は、リクエストの本文・URL・クエリから受け取らない。

### 破れたときの症状

ある利用者が、ほかの利用者のバックアップを取り込めてしまう、または上書き・削除できてしまう。

### 検出手順

```bash
grep -rn -i -E 'SELECT|UPDATE|DELETE|INSERT' server/internal
```

ヒットした SQL ごとに、`WHERE`（`INSERT` なら入れる値）に `user_id` があり、
その値が認証のミドルウェアが置いたものから来ているかを、呼び出し元までたどって確かめる。
handler で `r.PathValue`・`r.URL.Query()`・本文の JSON から `user_id` を読んでいたら違反。

### 誤検知しやすいケース

- ログインのときに `users` を `apple_user_id` で引くのは正しい（まだ `user_id` が分からない段階）
- ミドルウェアとログアウトで `auth_tokens` をトークンのハッシュで引く・消すのは正しい（送られたトークンそのものが本人の証明になる）
- `migrations/` の SQL は対象外
- `/health` の Ping は利用者の行に触らない

---

## メモがサーバーに渡る

### 不変条件

記録のメモは端末の外に出さない（憲法、ADR 0049）。
iOS の送る中身（`BackupSnapshot`）にメモの項目がなく、
サーバーのリクエストの型・テーブルにもメモの列がない。
Apple Music の曲名などのメタデータも、サーバーに持たない。

### 破れたときの症状

利用者が端末にだけ残ると思って書いたメモが、サーバーの DB とバックアップに残る。

### 検出手順

```bash
grep -rn -i -E 'memo|note' server/ Karaoke_support/Karaoke_support/Sources/Domain Karaoke_support/Karaoke_support/Sources/Data
```

`BackupSnapshot` と、その変換（SwiftData → `BackupSnapshot`）に、メモを写す行がないかを読む。
サーバーの JSON の型とマイグレーションに、メモの列がないかを読む。

### 誤検知しやすいケース

- `SingingSession` のメモそのもの（端末の中の `@Model`）は正しい
- コメントや文書の「メモは送らない」という記述

---

## 秘密がリポジトリに入る

### 不変条件

staging・本番の DB の URL、パスワード、鍵、トークンは、コード・テスト・文書・設定ファイルのどれにも入らない。
Secret Manager や手元の `server/.env`（コミットされない）に置く。

### 破れたときの症状

公開リポジトリなので、コミットした時点で誰でも DB に入れる。
後のコミットで消しても履歴に残るので、パスワードの変更が要る。

### 検出手順

```bash
git diff main...HEAD | grep -E '^\+' | grep -c -i -E 'neon\.tech|npg_|postgres(ql)?://[^@ ]+@|BEGIN [A-Z ]*PRIVATE KEY'
```

まず件数だけを数える（値を画面に出さない）。0 でなければ、
`git diff main...HEAD --stat` と合わせてどのファイルかを絞り、その行を読んで本物の値かどうかを判断する。
`.env` 以外の設定ファイルを足したときは、`password`・`secret`・`token` という名前の値も読む。
**報告には値を書き写さない。** `file:line` と種類だけを書く。

### 誤検知しやすいケース

- `server/compose.yaml`・`server/README.md`・`.claude/skills/karaoke-review/SKILL.md` の手元の Postgres（`karaoke:karaoke@localhost` や `@db`）は、手元専用で公開してよい値
- `server/README.md` の `gcloud secrets ...` のコマンドは、秘密の名前であって値ではない
- テストの偽物の値（`"db is down"` など）
- このファイルの検出手順そのもの（`npg_` などの検索の文字列）

---

## 流し済みのマイグレーションの書き換え

### 不変条件

`main` に入っている `server/migrations/` のファイルは、変更も削除もしない。
直すときは新しい番号のファイルを足す。

### 破れたときの症状

staging の DB は流し済みの番号を覚えているので、書き換えた中身は流れない。
手元では動くのに、staging では列やテーブルがなくて API が 500 を返す。

### 検出手順

```bash
git diff main...HEAD --name-status -- server/migrations
```

`A`（足した）だけなら正常。`M`（変えた）・`D`（消した）・`R`（名前を変えた）があれば違反。
足したファイルの番号が、今ある最後の番号の次になっているかも見る。

### 誤検知しやすいケース

- このブランチで足して、まだ `main` に入っていないファイルを直すのはよい。
  ただし、staging にすでに流していたら同じ問題が起きるので、本人に確かめる

---

## ログやエラーの返事に記録の中身や秘密が出る

### 不変条件

ログ（`slog`）とエラーの返事に、記録の中身（曲名・点数・気分）、
Apple のトークン・サーバーのトークン・`Authorization` ヘッダー、DB の URL を出さない（NFR-3）。
エラーの返事は決まった短い文にし、`err.Error()` をそのまま返さない。

### 破れたときの症状

Cloud Logging に利用者の曲名やトークンが残る。
エラーの返事から、DB の構成や内部の作りが外に見える。

### 検出手順

```bash
grep -rn -E 'slog\.|log\.Print|http\.Error|err\.Error\(\)|r\.Header|json\.Marshal' server/internal server/cmd
```

ログに渡している値が、リクエストの本文・ヘッダー・記録の型そのものでないかを読む。
エラーの返事（`http.Error` や `w.Write`）に `err` の中身が入っていないかを読む。

### 誤検知しやすいケース

- `health.go` で Ping のエラーをログに出すのは許している。
  pgx の接続のエラーにはユーザー名・DB 名・ホストが入るが、パスワードは入らない
- 件数・処理時間・ステータスコードのような、中身でない値のログ

---

## サーバーのトークンの扱い

### 不変条件

サーバーのトークンは、DB が漏れても、ログアウトした後も使えない（ADR 0054）。

- `crypto/rand` の 32 バイトから作る。`math/rand` は使わない
- DB にはハッシュ（SHA-256）だけを置き、照合もハッシュで行う。そのままの値は、DB・ログ・URL・クエリのどこにも置かない
- トークンを受け取るのは `Authorization: Bearer` だけ。クエリや Cookie からは読まない
- ミドルウェアは `expires_at` を見て、切れたものを通さない
- ログアウトは、送られたトークンのハッシュの行だけを消す
- トークンを返す返事には `Cache-Control: no-store` を付ける
- 記録やアカウントを扱う API は、どれもミドルウェアを通る。ルーターに足した API が素通りしていない

### 破れたときの症状

DB の中身やログを見た人が、ほかの利用者になりすましてバックアップを読める。
ログアウトしても、そのトークンが使えたままになる。

### 検出手順

```bash
grep -rn -E 'math/rand|crypto/rand|Bearer|expires_at|no-store|token' server/internal server/cmd
```

トークンを作る関数、保存する SQL、ミドルウェア、ログアウトの SQL を読み、上の条件を 1 つずつ確かめる。
`router.go` で、`/health` と `POST /v1/auth/apple` 以外の API がミドルウェアを通っているかを読む。

### 誤検知しやすいケース

- テストの中で、決まった値のトークン（`klog_test...` など）を作るのはよい
- `POST /v1/auth/apple` がミドルウェアを通らないのは正しい（まだトークンがない段階）
- 返事の本文でトークンを 1 回だけ返すのは正しい

---

## Apple のトークンの検証の抜け

### 不変条件

`POST /v1/auth/apple` は、Apple が今このアプリのために出したトークンだけを受け付ける（ADR 0054）。
根拠は Apple の「Verifying a user」の手順と、OpenID Connect Core 1.0 の 3.1.3.7（ID Token Validation）。

- 署名は `RS256` だけを受け付ける（`jwt.WithValidMethods`）
- 発行者が `https://appleid.apple.com`、宛先が設定のバンドル ID の 1 つだけ（ほかの宛先が混ざっていたら拒否。golang-jwt の `WithAudience` はどれか 1 つが合えば通すので、それだけでは足りない）、期限があって切れていない、発行時刻が 10 分以内。時計のずれの許容は 1 分まで
- 受け取った nonce の SHA-256 が、Apple のトークンの `nonce` と一致する
- 公開鍵は Apple の JWKS から keyfunc で取り、通信にタイムアウトがあり、知らない鍵の ID での取り直しに回数の制限がある
- 検証から先に渡すのは `sub` だけ
- 偽のトークン（ほかの鍵の署名・`RS256` 以外・発行者・宛先・期限・発行時刻・nonce の違い）がどれも失敗することを、テストで確かめている

### 破れたときの症状

ほかのアプリ向けや古い Apple のトークン、自分で作った偽のトークンでサインインでき、
ほかの利用者になりすましてバックアップを読める。

### 検出手順

```bash
grep -rn -E 'jwt\.(Parse|NewParser)|WithValidMethods|WithIssuer|WithAudience|WithExpirationRequired|WithIssuedAt|WithLeeway|keyfunc|nonce' server/internal
```

検証の関数を読み、上の条件が全部設定されているかを確かめる。
`jwt.WithIssuedAt` は未来の発行時刻をはじくための設定なので、それとは別に、発行時刻の古さを比べるコードがあるかを読む。
テストを読み、失敗する場合が 1 つずつテストになっているかを確かめる。

### 誤検知しやすいケース

- テストの中で、`RS256` 以外や違う発行者のトークンを作るのは正しい（失敗するのを確かめるため）
- テストで、自分で作った鍵を keyfunc の代わりに渡すのはよい
