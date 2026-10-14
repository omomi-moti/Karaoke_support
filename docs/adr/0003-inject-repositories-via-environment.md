# 0003. Repository は Protocol で定義し、`@Environment` で注入する

- 2026-07-28 ／ 承認
- 背景：ViewModel から SwiftData を直接触ると、テストで DB を差し替えられない。依存の渡し方を決める必要があった

## 比較した案
- A. ViewModel の中で具体的な Repository を作る、またはシングルトンを使う
- B. DI ライブラリを使う
- C. Repository を Domain の Protocol で定義し、App 起点で具体実装を作って `@Environment` で渡し、View が ViewModel の `init` に渡す

## トレードオフ
- A は簡単だが、テストで差し替えられない
- B は配線が楽になるが、外部依存が増える（憲法で DI ライブラリは使わない方針）
- C は EnvironmentKey を Repository ごとに書く手間がある

## 選んだ理由
- C。外部依存なしで差し替えられる。Repository テストは in-memory の `ModelContainer` で実際の SwiftData を使い、ViewModel テストはモックの Repository を `init` に渡して検証できている
- EnvironmentKey とプレビュー用のモックは App 層に置き、Data 層を SwiftUI に依存させない

## 見直す条件
- 依存が増えて EnvironmentKey の配線が負担になったとき
