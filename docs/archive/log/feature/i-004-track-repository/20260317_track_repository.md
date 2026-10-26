# feature/i-004-track-repository 実装ログ

**日付**: 2026-03-17  
**対象**: [I-004] TrackRepository 実装

---

## 概要

楽曲（Track）の永続化・取得・集計更新を行う Repository を実装した。Domain 層にプロトコル（TrackRepositoryProtocol）とエラー型（TrackRepositoryError）を定義し、Data 層に SwiftData による具体実装（SwiftDataTrackRepository）を配置。I-007A で DI 注入、I-009・I-013 で歌唱記録時の getOrCreate / incrementSingCount に利用する想定。

---

## 追加されたファイル

- **Sources/Domain/Repositories/TrackRepositoryProtocol.swift**
  - **TrackRepositoryProtocol**（`@MainActor` なプロトコル）
  - `searchLocal(query:)` - userEnteredName に対する検索、歌った回数降順
  - `getOrCreate(spotifyTrackId:userEnteredName:)` - 既存検索 or 新規作成。両方 nil は throw
  - `incrementSingCount(trackId:)` - 集計更新

- **Sources/Domain/Repositories/TrackRepositoryError.swift**
  - **TrackRepositoryError** - `bothIdsNil`, `trackNotFound(UUID)`

- **Sources/Data/SwiftData/SwiftDataTrackRepository.swift**
  - **SwiftDataTrackRepository**（`@MainActor` な final class）
  - searchLocal: userEnteredName に contains で部分一致、singCount 降順。空クエリは [] を返却
  - getOrCreate: spotifyTrackId 優先で検索、なければ userEnteredName で検索（手動入力曲は spotifyTrackId == nil を条件）、見つからなければ新規作成
  - incrementSingCount: trackId で取得し singCount += 1、updatedAt 更新。未存在時は throw

---

## 同一曲2回目以降のロジック

- getOrCreate は spotifyTrackId または userEnteredName で既存 Track を検索し、あればそれを返す
- RecordingViewModel（I-009）で getOrCreate で Track を取得し、SessionRepository.save で SingingSession を保存する
- 同一曲の2回目以降は getOrCreate が既存 Track を返し、SingingSession のみ追加される

---

## 影響範囲

| 対象 | 内容 |
|------|------|
| **Domain 層** | TrackRepositoryProtocol, TrackRepositoryError が追加。Track, SingingSession に依存。 |
| **Data 層** | SwiftDataTrackRepository が追加。SwiftData に依存。 |
| **今後の利用** | I-007A で DI 注入。I-009 歌唱記録入力で getOrCreate → incrementSingCount。I-021 ローカル検索で searchLocal。 |
