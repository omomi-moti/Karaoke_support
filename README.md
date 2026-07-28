# Hitokara Log — ヒトカラモバイルiOS

> 一人カラオケの歌唱体験を記録・振り返り、次の選曲を支援する iOS アプリ。

## なぜ作ったか

一人カラオケは「何を歌おう」と毎回迷い、歌った体験も記録されずリセットされる。既存のカラオケアプリは点数しか残さず、**なぜその曲を歌ったか（感情・文脈）が消える**。

Hitokara Log は、歌唱の意図を **Intent（🔥 Shout / 🌙 Emo / 🎤 Practice）** で記録し、スコア・メモとともに蓄積することで、過去の歌唱から「次に歌う曲」を提案する。単発で終わりがちな一人カラオケを **積み重なる体験** に変えるのが目的。

- カラオケボックスの通信が不安定 → **オフラインファースト**（ローカルDB完結）
- 体験の文脈が消える → **Intent** で感情をラベル化して永続化
- 歌唱記録が散逸する → **タイムマシン・マイアンセム**で振り返り＆次の選曲を支援

<p align="center">
  <img src="docs/screenshots/Simulator Screenshot - iPhone 17 - 2026-03-26 at 21.26.41.png" alt="選曲ホーム" width="160">
  <img src="docs/screenshots/Simulator Screenshot - iPhone 17 - 2026-03-26 at 21.27.04.png" alt="歌唱記録シート" width="160">
  <img src="docs/screenshots/Simulator Screenshot - iPhone 17 - 2026-03-26 at 21.27.17.png" alt="履歴" width="160">
  <img src="docs/screenshots/Simulator Screenshot - iPhone 17 - 2026-03-26 at 21.26.53.png" alt="タイムマシン" width="160">
  <img src="docs/screenshots/Simulator Screenshot - iPhone 17 - 2026-03-26 at 21.26.58.png" alt="マイアンセム" width="160">
</p>

---

## 技術スタック

| カテゴリ | 技術 |
|----------|------|
| 言語 | Swift 5.9+ |
| UI | SwiftUI |
| ローカル DB | SwiftData（iOS 17+） |
| 状態管理 | `@Observable`（Observation framework） |
| 非同期処理 | Swift Concurrency（async/await） |
| アーキテクチャ | MVVM + Repository、手動 DI（`@Environment`） |
| テスト | XCTest（14 ユニットテスト + 1 UI テスト） |
| 最低対応 OS | iOS 17.0 |

---

## クイックスタート

**前提**: Xcode 15.0+ / macOS Sonoma+ / iOS 17.0+ シミュレータ

```bash
git clone https://github.com/omomi-moti/Karaoke_support.git
cd Karaoke_support
open Karaoke_support/Karaoke_support.xcodeproj
# Cmd + R でビルド & 実行（iPhone シミュレータ iOS 17+）
```

起動後: 選曲タブ → ツールバー「記録を追加」→ 曲名入力 → スコア → Intent → 保存


---

## ディレクトリ構成

<details>
<summary>Sources/ ツリー（クリックで展開）</summary>

```
Sources/
├── App/                  # @main、DI（EnvironmentKey）、プレビュー用モック
├── Presentation/         # View + ViewModel（画面単位でサブフォルダ）
│   ├── Recording/        # 歌唱記録シート
│   ├── History/          # 履歴一覧
│   ├── Songs/            # 選曲タブ・インテントタブ
│   ├── Root/             # TabView
│   ├── Common/           # 共通コンポーネント
│   └── Theme/            # 色トークン
├── Domain/               # Protocol・Model（フレームワーク非依存）
│   ├── Models/           # Track, SingingSession, Intent
│   ├── Repositories/     # SessionRepository, TrackRepository, InsightRepository
│   └── Helpers/
└── Data/                 # 具体実装
    ├── SwiftData/        # Repository実装
    └── Network/          # NetworkMonitor
```

</details>

---

## テスト

```bash
# 全テスト実行
xcodebuild test \
  -project Karaoke_support/Karaoke_support.xcodeproj \
  -scheme Karaoke_support \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

| テスト対象 | 内容 |
|-----------|------|
| Repository（4ファイル） | 冪等性・削除・更新・Intent フィルター |
| HistoryViewModel（3ファイル） | ページネーション・ソート・非同期競合 |
| IntentTabViewModel | インサイト取得・並行制御・月次統計 |
| RecordingSheetViewModel | 新規/編集の分岐 |
| Domain ヘルパー | 曲名表示・Empty State文言 |

---

## ドキュメント

| 内容 | ファイル |
|------|---------|
| プロダクト概要・Intent設計 | [`docs/product_overview.md`](docs/product_overview.md) |
| 技術的な工夫・解決策 | [`docs/technical_decisions.md`](docs/technical_decisions.md) |
| アーキテクチャ・データフロー | [`docs/architecture.md`](docs/architecture.md) |
| 開発プロセス（Spec駆動・AI活用） | [`docs/development_process.md`](docs/development_process.md) |
| V1 Issue一覧・完了チェック | [`docs/v1_issues.md`](docs/v1_issues.md) |
| 画面遷移設計 | [`docs/v1_navigation_songs_recording.md`](docs/v1_navigation_songs_recording.md) |
| 手動QA手順 | [`docs/manual_qa_I008_I009_record_save.md`](docs/manual_qa_I008_I009_record_save.md) |

---

## Author

- **GitHub**: [@omomi-moti](https://github.com/omomi-moti)
