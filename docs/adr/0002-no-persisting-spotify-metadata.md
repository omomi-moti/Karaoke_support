# 0002. Spotify のメタデータは永続化せず、曲は ID とユーザー入力だけ持つ

- 2026-07-28 ／ 承認
- 背景：Spotify API の規約で、曲名・アーティスト名・アートワークなどの永続保存が禁止されている（憲法 I）。一方で、Spotify 未連携でも記録と振り返りはできるようにしたい

## 比較した案
- A. 取得したメタデータを SwiftData や UserDefaults に保存する
- B. `Track` には `spotifyTrackId` とユーザーが入力した曲名（`userEnteredName`）だけを持ち、表示用のメタデータは V2 でインメモリの TTL キャッシュ（24h）から取る

## トレードオフ
- A は実装が簡単でオフラインでも曲名を出せるが、規約違反になる
- B は規約を守れるが、Spotify 由来の曲はオンラインで取得するまで曲名を出せない

## 選んだ理由
- B。規約違反は選べない。V1 は `userEnteredName`（ユーザー生成データなので永続化してよい）で曲名を出し、Spotify なしでも体験が完結するようにした
- `Track` の初期化子を Spotify 用（`spotifyTrackId` 必須）と手入力用（`userEnteredName` 必須）に分け、`private init` で代入を一か所にまとめた。Spotify 連携を足すときに型の保証を壊さないため
- Spotify 由来で `Track` を作るときは `userEnteredName` を保存しない（`SwiftDataTrackRepository.getOrCreate`）

## 見直す条件
- Spotify の規約が変わったとき

関連：[constitution.md](../../.specify/memory/constitution.md)（I. Spotify API 規約準拠）
