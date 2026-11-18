# TestFlight と App Store に上げる手順

外部テスターには Beta のビルド、App Store には Release のビルドを出す（ADR 0053・0064）。Beta にはアカウントとバックアップが入っているので、**Beta のビルドを App Store の審査に出さない**。

Beta と Release は同じビルド番号の列を使う。どの番号が Beta かは、下の「Beta のビルド番号の控え」で見分ける。

## Beta を TestFlight に上げる

前に確かめる：`Karaoke_support/Config/Local.xcconfig` があり、staging のホスト名が入っている。ないとビルドは通るが、アカウントの欄が出ないアプリができる（ADR 0064）。

1. ビルド番号（Build）を、前に上げたどの番号よりも大きくする
2. スキームを `Karaoke_support-Beta` にし、行き先を Any iOS Device にする
3. Product → Archive
4. Organizer で Distribute App → App Store Connect に上げる
5. スキームを `Karaoke_support` に戻す。戻し忘れると、次の Archive が Beta になる
6. 下の「Beta のビルド番号の控え」に番号を足す
7. App Store Connect の TestFlight で、ビルドの処理が終わったら：
   - 「テスト内容」を入れる。ビルドごとなので毎回入れる（下の「テスト内容の文」）
   - グループ「Dev」（内部・外部）に足す
   - 外部テストの審査（Beta App Review）を求められたら出す。ビルド 28 では審査はなかった
8. テスターには、TestFlight アプリで更新してもらう。更新しないと前の版のままになる

Distribute App で、Sign in with Apple が入っていないと言われたとき：配布用のプロファイルが古い。手元のプロファイルを消し、Xcode の Settings → Accounts で Download Manual Profiles を押してから、Distribute App をやり直す。

### テスト情報

App Store Connect の TestFlight → テスト情報。版ごとではなく、アプリに 1 つ。

- サインインが必要：オフ。サインインしなくても使え、サインインは Sign in with Apple だけなので、渡すアカウントがない
- 審査用のメモ：

  ```text
  Sign-in is optional. The app works without an account.
  Account and backup use Sign in with Apple only. You can sign in with your own Apple ID from the Settings tab.
  ```

- フィードバックの連絡先：テスターに見えるので、サポートのページ（`/support/`）と同じ公開用のアドレスにする
- プライバシーポリシーの URL：`https://omomi-moti.github.io/Karaoke_support/privacy/`

### テスト内容の文

試してほしいこと（サインイン → バックアップをオン → アプリを閉じる → 入れ直すか別の端末に入れる → 取り込む）を番号で書き、最後に次の文を入れる。

```text
記録の正は端末です。サーバーの控えは試し用で、消すことがあります。消すときは先にお知らせします。
```

## Release を App Store に出す

1. ビルド番号を、前に上げたどの番号よりも大きくする
2. スキームが `Karaoke_support` であることを確かめ、行き先を Any iOS Device にする
3. Product → Archive → Distribute App
4. App Store Connect の配信で、審査に出す版のビルドを選ぶ。**下の控えにある番号は選ばない**
5. 審査に出す前に、選んだビルドを TestFlight の内部テストで入れ、設定にアカウントの欄がないことを確かめる

## Beta のビルド番号の控え

| ビルド | 版 | 上げた日 |
|---|---|---|
| 28 | 1.0 | 2026-11-17 |
