# ドキュメント・Issue クロスチェックレポート

**作成日**: 2026-03-12  
**対象**: spec.md, basic_design.md, detailed_design.md, issues.md

---

## 1. 矛盾点・抜け漏れの分析レポート

### 1.1 重要な前提仕様との整合性

| 前提仕様 | spec | basic_design | detailed_design | issues |
|----------|------|--------------|-----------------|--------|
| メタデータ非永続化 | ✓ FR-001, FR-017 | △ 軽量キャッシュの記述が古い | ✓ 3.1〜3.5 で明記 | ✗ タスク不足 |
| Spotify クレジット | ✓ FR-018 | ✗ 記載なし | ✓ 3.5 | ✗ タスク不足 |
| プライバシーポリシー導線 | ✓ FR-019 | ✗ 記載なし | ✓ 3.5 | ✗ タスク不足 |

---

### 1.2 矛盾点の詳細

#### 矛盾1: TrackRepository の API 定義（解消済み）

| ドキュメント | 記述 |
|--------------|------|
| **issues.md** I-004 | `searchLocal(query)`, `getOrCreate(spotifyTrackId?, userEnteredName?)` |
| **detailed_design.md** | `searchLocal(query)`, `getOrCreate(spotifyTrackId?, userEnteredName?)` |

**指摘（履歴）**: 当初、issues.md の I-004 が detailed_design と不一致であり、`search` → `searchLocal`、`getOrCreate` の引数に `userEnteredName` を追加する必要があった。  
**対応状況**: 当該 PR 内で issues.md I-004 を修正し、現在は detailed_design.md と同じ API 定義となっており、矛盾は解消済み。

---

#### 矛盾2: 最近再生した曲のキャッシュ戦略（当初の矛盾・解消済み）

| ドキュメント | 記述（当初） |
|--------------|--------------|
| **issues.md** I-025 | 「UserDefaultsキャッシュ」 |
| **basic_design.md** 2.1 | 「UserDefaults」「起動時の即時表示に適する」 |
| **raw_spec.md** 5.3, **detailed_design.md** 3.4 | 「24時間以内の一時キャッシュ」「永続化しない」 |

**指摘（履歴）**: 当初は、Spotify API 規約によりメタデータの永続保存が禁止されているにもかかわらず、UserDefaults に永続化するよう読める記述があり、24時間以内の一時キャッシュという方針と矛盾していた。  
**対応状況**: 本PRで issues.md I-025, basic_design.md 2.1, raw_spec.md 5.3, detailed_design.md 3.4 を「24時間以内のインメモリ一時キャッシュ」「永続化しない」方針に揃えて修正済み。Spotify メタデータはディスクへ保存せず、アプリ再起動で初期化されるインメモリキャッシュのみを用いる設計となっている。

---

#### 矛盾3: basic_design.md の参照バージョン

| 項目 | 記述 |
|------|------|
| **basic_design.md** 冒頭 | 「docs/raw_spec.md v4.0」 |
| **raw_spec.md** | v4.1（Spotify 規約・メタデータ非永続化対応） |

**指摘**: basic_design の参照を v4.1 に更新し、5.3 キャッシュ戦略に「24時間以内の一時キャッシュ」「永続化しない」を追記する必要あり。

**対応状況**: basic_design.md 冒頭の参照バージョンは `docs/raw_spec.md v4.1` に更新済み。キャッシュ戦略は §2.1 技術スタック「軽量キャッシュ」行のインメモリ説明、および §5.1 運用設計に規約準拠の方針を記述済み。矛盾は解消済み。✓

---

### 1.3 抜け漏れの詳細

#### 抜け漏れ1: TrackMetadataService / TrackMetadataCache の実装タスク

**状況**: detailed_design.md のクラス図・3.3 に `TrackMetadataService` と `TrackMetadataCache` が定義されているが、issues.md に該当タスクが存在しない。

**影響範囲**:
- 履歴画面（I-014）: Phase 3 以降、Spotify 曲の曲名表示に必要
- タイムマシン（I-018）・マイアンセム（I-019）: Phase 3 以降、Spotify 曲がランクインした場合に必要
- 検索画面（I-020）: ローカル結果の Spotify 曲表示
- Spotify 視聴履歴タブ（I-026）: メタデータ表示

**推奨**: Phase 3 に「TrackMetadataService と TrackMetadataCache 実装」を新規追加。I-023 OAuth、I-024 トークンリフレッシュの後に配置。

---

#### 抜け漏れ2: Spotify クレジット配置（FR-018）

**状況**: spec.md FR-018 で「検索結果画面および設定画面に Spotify クレジットを配置」と規定されているが、issues.md に該当タスクがない。

**推奨**: I-020（検索画面）と I-033（設定画面）の概要に「Spotify クレジット（Powered by Spotify 等）の配置」を明記して包含する。

---

#### 抜け漏れ3: プライバシーポリシーリンク設置（FR-019）

**状況**: spec.md FR-019 で「プライバシーポリシー（Web）へのリンクをアプリ内に設置」と規定されているが、issues.md に該当タスクがない。

**推奨**: I-033（設定画面）の概要に「プライバシーポリシーへのリンク設置」を明記して包含する。

---

#### 抜け漏れ4: I-002 SwiftData モデルの仕様詳細

**状況**: Track に `userEnteredName` を追加する設計変更が detailed_design に反映されているが、I-002 の概要が「Track, SingingSession の @Model 定義」のまま。メタデータ非永続化・userEnteredName の役割がタスクに反映されていない。

**推奨**: I-002 の詳細に「Track に spotifyTrackId, userEnteredName のみ。曲名・アーティスト名・アートワークは永続化しない（Spotify API 規約）」を追記。

---

#### 抜け漏れ5: ローカル検索の対象フィールド（I-021）

**状況**: Track に曲名を永続化しないため、ローカル検索は `userEnteredName` に対する検索となる。Spotify Track ID のみの曲は曲名で検索できない。

**推奨**: I-021 の概要に「userEnteredName に対するインクリメンタル検索。Spotify Track ID のみの曲は検索対象外（Phase 3 以降は TrackMetadataCache にヒットすれば表示可能）」を追記。

---

### 1.4 フェーズ分け・依存関係の検証

#### 依存関係の妥当性

- **I-013**: I-003, I-004, I-008, I-009, I-010, I-011, I-012 に依存 → 妥当
- **I-018, I-019**: I-005 InsightRepository に依存 → Phase 2 時点では userEnteredName のみの Track のため問題なし。Phase 3 以降は TrackMetadataService が必要だが、I-018/019 は Phase 2 で完了するため、Phase 3 で「インサイトの Spotify 曲メタデータ表示」を I-028 または別タスクで対応する必要あり
- **I-025 → I-026**: 妥当。I-026 は I-025 のキャッシュを表示
- **I-028**: オフラインフォールバック。ローカルキャッシュ（TrackMetadataCache）表示を含む → TrackMetadataService/Cache に依存する必要あり

#### ブロック関係の不足

- **TrackMetadataService / TrackMetadataCache**: I-025, I-026, I-027, I-028 の前に完了している必要がある。I-023, I-024 の後に新規 Issue を挿入。

#### 循環依存

- 確認済み。循環依存なし。✓

---

### 1.5 推奨修正一覧

| 対象 | 修正内容 |
|------|----------|
| I-002 | メタデータ非永続化、userEnteredName の役割、Why を追記 |
| I-004 | searchLocal、getOrCreate(spotifyTrackId?, userEnteredName?)、Why を追記 |
| I-020 | Spotify クレジット配置を概要に追加 |
| I-021 | userEnteredName 検索である旨、Why を追記 |
| I-025 | 24時間以内の一時キャッシュ、永続化禁止、Why を追記 |
| Phase 3 新規 | TrackMetadataService と TrackMetadataCache 実装（Why 含む） |
| I-026 | TrackMetadataService 経由のメタデータ表示を追記 |
| I-027 | 検索結果のメタデータをキャッシュに載せる旨を追記 |
| I-028 | TrackMetadataCache からのフォールバック表示を追記 |
| I-033 | Spotify クレジット、プライバシーポリシーリンクを概要に追加 |
| basic_design.md | （別途）参照 v4.1、キャッシュ戦略の規約準拠を追記 |

---

## 2. 修正版 issues.md の適用

上記の指摘を解消した修正版 issues.md を `docs/issues.md` に出力済み。

### 実施した主な変更

1. **I-002**: メタデータ非永続化、userEnteredName の役割を概要に追記
2. **I-004**: searchLocal、getOrCreate(spotifyTrackId?, userEnteredName?) に修正
3. **I-020**: Spotify クレジット配置を概要に追加
4. **I-021**: userEnteredName 検索である旨を追記
5. **I-024A**（新規）: TrackMetadataService / TrackMetadataCache 実装
6. **I-025**: 24時間以内の一時キャッシュ、永続化禁止を追記
7. **I-026**: TrackMetadataCache 経由のメタデータ表示を追記
8. **I-027**: 検索結果のメタデータをキャッシュに載せる旨を追記
9. **I-028**: TrackMetadataCache からのフォールバック表示を追記
10. **I-033**: Spotify クレジット、プライバシーポリシーリンクを概要に追加
11. **セクション3 タスク詳細**: 各タスクの Why・ベストプラクティスを新設
12. **依存関係**: I-024A を追加し、I-025, I-027, I-028 のブロック関係を更新
