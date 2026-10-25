# 0027. Repository の EnvironmentKey は、プロトコルを Sendable にし、初期値をメインアクターの外で作れるようにする

- 2026-10-25 ／ 承認（2026-10-24 に提案）
- 背景：Repository の EnvironmentKey は `@MainActor static let defaultValue` で書いていて、「`EnvironmentKey` への準拠がメインアクターをまたぐ」という警告が出る（Swift 6 言語モードではエラー）。#115 で `trackStatsRepository` のキーを足したときに同じ警告が出たので、どう直すのが正しいかを調べた

## 比較した案
- A. 今のまま（`@MainActor static let`）にして、警告を残す
- B. `nonisolated(unsafe) static let` や `@preconcurrency` で警告を消す
- C. プロトコルを `Sendable` にし、プレビュー用 Repository の `init` を `nonisolated` にして、`defaultValue` から `@MainActor` を外す
- D. 初期値を `@Entry` で書く

## トレードオフ
- A は変えなくて済むが、Swift 6 言語モードに上げるとビルドが通らない
- B は 1 行で済むが、コンパイラの検査を外すだけで、本当に安全かは誰も確かめていない状態になる
- C は 1 つのキーにつき 3 か所変える必要があるが、「別のスレッドに渡しても安全」なことをコンパイラが確かめた状態になる。後から状態を持つ実装を足したとき（`@MainActor` の付け忘れなど）も、書いたその場でエラーになる
- D は初期値を読むたびに作り直すので、参照型の Repository には向かない（#112）。初期値をメインアクターの外で作れないという警告の原因も残る

## 選んだ理由
- C。次の 3 段で警告の原因を 1 つずつ取り除いている
  1. `EnvironmentKey` の `defaultValue` はメインアクターの外からも読まれる前提なので、`@MainActor` を付けると要件と合わない → `@MainActor` を外す
  2. 外すと、初期値はメインアクターの外で作られることがある → プレビュー用 Repository の `init` を `nonisolated` にする。プレビュー用 Repository は状態を持たないので、どのスレッドで作っても安全
  3. `static let` は全部のスレッドから読める共有の値なので、型が Sendable でなければならない。型は `any プロトコル` で、コンパイラは箱の中身が Sendable かをプロトコルに書いてあることでしか判断できない → プロトコルを `Sendable` にして「準拠する型は全部 Sendable」という条件を契約に入れる
- プロトコルの `@MainActor` は「メソッドはメインスレッドで呼ぶ」という呼び出し方の約束で、Sendable は「値そのものを別のスレッドに渡しても安全」という値の性質の約束。別の約束なので、`@MainActor` だけでは Sendable にならず、明示が要る
- `@MainActor` のクラスはもともと Sendable なので、SwiftData の実装（`SwiftDataSessionRepository` など）は変えずに済む
- 確かめたこと：`trackStatsRepository` のキーでこの 3 つを変え、`SWIFT_STRICT_CONCURRENCY=complete` でビルドして、このキーの警告が出ないことを確かめた。そのあと、ほかのキーと書き方をそろえるため元に戻した
- #112 で、Repository の 4 つのキー（Session ／ Track ／ Insight ／ TrackStats）にまとめて当てた。状態を持つ `PreviewSessionRepository` も、初期値付きのプロパティのまま `nonisolated init` でビルドが通った。テストのモック 22 個はすべて `@MainActor` のクラスなので、変えずに済んだ
- 同じ警告が出ていた `NetworkMonitor` はキーをやめて `@Environment(NetworkMonitor.self)` で渡し、クロージャのキーは `@Entry` にした。どれをどの書き方にするかの基準は [0031](0031-environment-values-by-default-identity.md)

## 見直す条件
- Swift 6 言語モードに上げるとき（この直し方で警告もエラーも出ないかを確かめる）
- プレビュー用 Repository が状態を持つようになり、`init` を `nonisolated` にできなくなったとき

関連：#112、#115、[0031](0031-environment-values-by-default-identity.md)
