# 0031. 環境に置くものは、初期値に同一性があるかで書き方を分ける

- 2026-10-25 ／ 承認
- 背景：環境に置く値（`EnvironmentValues`）が 3 通りの書き方で混ざっていて、厳しい並行性チェック（`SWIFT_STRICT_CONCURRENCY=complete`）で 7 件の警告が出ていた。1 行で書ける `@Entry` に統一するかを検討した（#112）

## 比較した案
- A. 全部 `@Entry` にする
- B. 全部 `EnvironmentKey`＋`static let` のままにする
- C. 初期値に同一性（状態）があるかで分ける。値・クロージャは `@Entry`、状態を持つ参照型は `EnvironmentKey`＋`static let`、アプリに 1 つの `@Observable` のクラスは `@Environment(型)`

## トレードオフ
- A は一番短い。ただ `@Entry` の初期値は、展開すると `static var defaultValue: T { get { 初期値 } }` になり、注入していない場所で読むたびに作り直される。参照型だと読むたびに別のインスタンスになり、状態を持つ `PreviewSessionRepository` は、プレビューで保存した記録を次に読んだときには覚えていない。初期値が `@MainActor` の `init` を呼ぶ場合（今のプレビュー用 Repository）は、ビルドエラーにもなる
- B は初期値を 1 回だけ作れる。ただ書く量が多く、クロージャを全スレッドで共有する `static let` が並行性チェックの警告になる
- C は書き方が 3 つになるが、それぞれの性質に合った書き方になり、警告もなくせる

## 選んだ理由
- C。基準は「値型か参照型か」ではなく「初期値に状態・同一性があるか」。作り直しても困らないもの（値・クロージャ）は `@Entry`、困るもの（状態を持つ参照型）は `static let` で 1 回だけ作る
- 確かめたこと（2026-10-25、Swift 6.2）：作るたびに番号が増えるクラスを両方の書き方で置いて 2 回読むと、`@Entry` は別のインスタンス、`static let` は同じインスタンスだった。注入した値は `@Entry` でも同じインスタンスが返る。作り直しが問題になるのは、注入しなかったとき（プレビュー・注入し忘れ）だけ
- `NetworkMonitor` は `@MainActor @Observable` の具体的なクラスで、アプリに 1 つしかない。型を鍵にする `.environment(networkMonitor)`／`@Environment(NetworkMonitor.self)` で渡し、キーの定義をなくした
  - この書き方には初期値がなく、入れ忘れると読んだ瞬間に落ちる。App の 1 か所で入れているので本番では起きず、起きるとしても開発中なのですぐ気づける
  - 前の初期値（監視しない `NetworkMonitor`）は `isOnline` がずっと `false` なので、入れ忘れると、つながっているのに「オフライン」の帯が出続けていた。黙って偽物が使われるより、落ちて気づける方を取った
- Repository はプロトコル型（`any SessionRepositoryProtocol`）で `@Observable` のクラスでもないので、型を鍵にする書き方は使えない。キーのまま、メインアクターをまたぐ警告は [0027](0027-sendable-repository-protocols-for-environment-keys.md) の直し方で消した
- 結果、厳しい並行性チェックで環境まわりの警告 7 件（Repository 4・NetworkMonitor 1・クロージャ 2）が 0 件になった

## 見直す条件
- 状態を持つ値を新しく環境に置くとき（この基準でどの書き方にするかを決める）
- SwiftUI で `@Entry` の初期値の扱いが変わったとき
- `NetworkMonitor` を読む画面が増え、プレビューでの入れ忘れが続くとき

関連：#112、[0003](0003-inject-repositories-via-environment.md)、[0027](0027-sendable-repository-protocols-for-environment-keys.md)
