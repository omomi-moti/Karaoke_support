# 0055. staging のつなぎ先は手元の xcconfig に置き、ないときはアカウントの機能を出さない

- 2026-11-11 ／ 承認
- 背景：iOS から staging にサインインする（#152）ために、Debug のビルドへ staging の URL を渡す必要がある。リポジトリは公開で、staging の Cloud Run は誰でも呼べる。レート制限はまだなく、`/health` を叩かれ続けると Neon の無料枠を使い切って月末まで止まる（ADR 0051・0053、Issue 5 で直す）。あわせて、URL がないビルドで、アカウントの Repository を環境にどう置くかを決める

## 比較した案

1. URL の置き場所
- A. コミットしない `Config/Local.xcconfig` に書き、コミットする `Config/Debug.xcconfig` から `#include?` で読み込む
- B. `project.pbxproj` の Debug のビルド設定に書いてコミットする
- C. スキームの環境変数（`KARAOKE_API_BASE_URL`）だけで渡す

2. URL がないときの、環境のアカウントの Repository
- A. 初期値を nil にし、nil のときはアカウントの欄を出さない
- B. ほかの Repository と同じく、プレビュー用の偽物を初期値にする

3. 環境のキーの書き方
- A. `@Entry`
- B. `EnvironmentKey`＋`static let`（ほかの Repository と同じ）

## トレードオフ

- 1-A は URL が GitHub に出ない。代わりに、clone したあと `Local.xcconfig` を 1 つ手で作る手順が要る。ないときはビルドは通り、アカウントの欄が出ないだけ。1-B は一番簡単で、clone してすぐ動くが、URL が公開の場所に出て、ボットに拾われやすくなる。1-C は Xcode から起動したときしか効かず、実機でホーム画面から開き直すとつなぎ先がなくなる
- URL は秘密ではない（Beta のアプリからも取り出せる）。1-A が守るのは「公開のリポジトリから見つけやすくしない」ことだけで、本当の守りはレート制限（Issue 5）
- 2-A はつなぎ先がないビルドで、偽のアカウントが本物のアプリに出ない。記録・履歴・選曲は今までどおり動く（NFR-1）。代わりに、プレビューでは偽物を自分で注入する必要がある。2-B は書き方がほかの Repository とそろうが、注入し忘れたとき、本物のアプリに偽物のサインイン済みの画面が黙って出る
- 3 は、ADR 0031 の基準（初期値に同一性があるか）で決まる。初期値が nil なら、読むたびに作り直しても同じなので 3-A で足りる。3-B は、ほかの Repository と形がそろう以外の利点がない

## 選んだ理由

- 1 は A。レート制限が入るまでは、staging の URL を公開の場所に書かないほうが安全。xcconfig にしておけば、Issue 5 で Beta のビルド設定を作るときも、同じ形で使える
- 2 は A。黙って偽物が使われるより、機能が出ないほうが気づきやすく、記録の機能にも影響しない
- 3 は A。ADR 0031 の基準どおりに選ぶ。初期値をプレビュー用の Repository に戻すことがあれば、そのときに B に戻す

## 決めたこと

- `Karaoke_support/Config/Debug.xcconfig` をアプリの Debug の土台にし、`#include? "Local.xcconfig"` だけを書く。Release には割り当てない
- `Local.xcconfig` は `.gitignore` に入れる。書き方は `Local.xcconfig.example`。xcconfig では `//` から後ろがコメントになるので、`https:/$()/…` と書く
- Info.plist の `APIBaseURL` が `$(API_BASE_URL)` を受け、`APIConfiguration` が読む。スキームの環境変数 `KARAOKE_API_BASE_URL` があれば、そちらを使う。トークンを平文で送らないように、`https` だけを受け付け、`http` は手元のサーバー（`localhost`・`127.0.0.1`・`::1`）だけ許す
- URL がないとき、`AppDependencies` はアカウントの Repository を作らず、環境の `accountRepository` は nil のまま

## 見直す条件

- Issue 5 で Beta のビルド設定を作るとき（Beta 用の xcconfig と、TestFlight に上げるビルドへの URL の渡し方）
- レート制限が入り、URL が公開の場所にあっても困らなくなったとき
- CI でビルドするようになり、`Local.xcconfig` を作る手順が負担になったとき

関連：#152、[0031](0031-environment-values-by-default-identity.md)、[0051](0051-public-cloud-run-with-caps.md)、[0053](0053-beta-testers-and-auto-backup.md)
