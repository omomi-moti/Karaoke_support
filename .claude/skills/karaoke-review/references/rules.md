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

`docs/constitution.md` の Core Principle I。
メタデータのキャッシュはインメモリのみ許可され、TTL は最長 24 時間、
アプリ再起動時にクリアされることが条件になっている。

### 検出手順

1. `Track` / `SingingSession` など `@Model` 型へのプロパティ追加を確認する
2. `grep -rn 'UserDefaults' Sources` — V1 時点では 0 件が正常
3. API 応答の型から `@Model` のプロパティへ代入している箇所を探す
4. ファイル書き込み（`FileManager`, `Data.write`, `Codable` の永続化）を探す

### 現状

`Data/Spotify/` と `Data/Cache/` は `.gitkeep` のみで空。
V1 時点では検出対象が存在しない。**V2 で Spotify 連携を実装する時点で発火する**ルール。

### 誤検知しやすいケース

- `spotifyTrackId` の保存は**正しい**。識別子は永続化してよい
- Spotify ID を短縮して表示用文字列にする処理（`TrackDisplayTitle`）も問題ない。
  表示のために加工しているだけで、メタデータを保存していない
- インメモリの TTL キャッシュは**許可されている**。
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
    return true
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
guard !isSaving else { return false }
guard validate() else { return false }
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
