# Hitokara Log — ヒトカラモバイルiOS

> 一人カラオケの歌唱体験を記録・振り返り、次の選曲を支援する iOS アプリ。

## なぜ作ったか

一人カラオケは「何を歌おう」と毎回迷い、歌った体験も記録されずリセットされる。既存のカラオケアプリは点数しか残さず、**なぜその曲を歌ったか（感情・文脈）が消える**。

Hitokara Log は、歌唱の意図を **Intent（🔥 Shout / 🌙 Emo / 🎤 Practice）** で記録し、スコア・メモとともに蓄積することで、過去の歌唱から「次に歌う曲」を提案する。単発で終わりがちな一人カラオケを **積み重なる体験** に変えるのが目的。

- カラオケボックスの通信が不安定 → **オフラインファースト**（ローカルDB完結）
- 体験の文脈が消える → **Intent** で感情をラベル化して永続化
- 前に歌って良かった曲を忘れる → **保存直後の提案**と**選曲画面**で、自分の記録（気分・点数・ハート）から次の 1 曲を思い出せる

<p align="center">
  <img src="docs/screenshots/songs.png" alt="選曲画面" width="160">
  <img src="docs/screenshots/recording.png" alt="歌唱記録シート" width="160">
  <img src="docs/screenshots/after-save.png" alt="保存直後の次の1曲の提案" width="160">
  <img src="docs/screenshots/history.png" alt="履歴" width="160">
  <img src="docs/screenshots/track-detail.png" alt="曲詳細" width="160">
</p>

---

## 技術スタック

| カテゴリ | 技術 |
|----------|------|
| 言語 | Swift 6.2（Xcode 26 付属のコンパイラ。言語モードは 5.9、Approachable Concurrency を有効） |
| UI | SwiftUI |
| ローカル DB | SwiftData |
| 状態管理 | `@Observable`（Observation framework） |
| 非同期処理 | Swift Concurrency（async/await） |
| アーキテクチャ | MVVM + Repository、手動 DI（`@Environment`） |
| テスト | Swift Testing・XCTest（ユニットテスト。UI テストは起動の確認だけ） |
| 最低対応 OS | iOS 26.0 |

---

## クイックスタート

**前提**: Xcode 26.0+ / iOS 26.0+ シミュレータ

```bash
git clone https://github.com/omomi-moti/Karaoke_support.git
cd Karaoke_support
open Karaoke_support/Karaoke_support.xcodeproj
# Cmd + R でビルド & 実行（iPhone シミュレータ iOS 26+）
```

起動後: 右下の「＋」ボタン → 曲名入力 → スコア（任意）→ Intent → また歌いたいならハート → 保存。保存すると履歴タブに移り、同じ気分で前に歌った曲（今日まだ歌っていないもの）があれば「次はこの曲？」で次の 1 曲の候補が出る。ハートを付けた曲は上に出る。「もっと見る」で選曲画面に移り、気分を切り替えて候補を見られる（選曲タブと同じ画面）


---

## ディレクトリ構成

<details>
<summary>Sources/ ツリー（クリックで展開）</summary>

```
Sources/
├── App/                  # @main、起動時の組み立て（AppDependencies）、DI（EnvironmentKey）、プレビュー用モック
├── Presentation/         # View + ViewModel（画面単位でサブフォルダ）
│   ├── Recording/        # 歌唱記録シート
│   ├── AfterSave/        # 保存直後のシート（次の 1 曲の提案）
│   ├── History/          # 履歴一覧
│   ├── TrackDetail/      # 曲詳細
│   ├── Songs/            # 選曲タブ
│   ├── Selection/        # 選曲画面（また歌いたい・今の気分に合う曲）
│   ├── Search/           # 検索タブ
│   ├── Settings/         # 設定タブ
│   ├── Root/             # TabView・シートの切り替え・DB を開けなかったときの画面
│   ├── Common/           # 共通コンポーネント
│   └── Theme/            # 色トークン
├── Domain/               # Protocol・Model（フレームワーク非依存）
│   ├── Models/           # Track, SingingSession, Intent, RecordSource 等
│   ├── Repositories/     # Session / Track / Insight / TrackStats の Repository
│   └── Helpers/          # 次の 1 曲の計算、曲名の候補の並べ方 等
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
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

| テスト対象 | 内容 |
|-----------|------|
| 起動時の組み立て（AppDependencies） | DB と Repository の作成・DB を開けなかったときの throw |
| Repository（SwiftData） | 冪等性・削除・更新・取得（Intent 別・曲別）・曲ごとの集計（最新のハートを含む）・記録の入口と、その数・ハートの保存と更新 |
| HistoryViewModel・並び順 | ページネーション・ソート・非同期競合 |
| RecordingSheetViewModel | 新規／編集の分岐・保存した記録の要約・曲と気分を入れて開く・記録の入口（提案から／選曲画面から／それ以外）・ハート（新規・編集）・曲名の候補（もしかして）・点数入力・歌唱日時 |
| 保存直後のシート | 次の 1 曲の候補の用意・理由の文言（選曲画面の気分付きを含む） |
| SelectionViewModel | 選曲画面の読み込み・最初の気分・気分の切り替え・再試行・古い結果の上書き防止 |
| SettingsViewModel | 提案から記録した数の読み込み・再試行 |
| TrackDetailViewModel・統計 | 曲ごとの点数推移・直近スコアと前回比 |
| Domain ヘルパー・共通 | 次の 1 曲の計算（ハート付きを上に）・選曲画面のセクション分け・曲名表示・曲名候補の並べ方・点数の右詰め入力と表示・Empty State 文言 |

---

## ドキュメント

| 内容 | ファイル |
|------|---------|
| docs の目次（どれが正か） | [`docs/README.md`](docs/README.md) |
| プロダクト概要・Intent設計 | [`docs/product_overview.md`](docs/product_overview.md) |
| 技術判断の記録（ADR） | [`docs/adr/`](docs/adr/README.md) |
| アーキテクチャ・データフロー | [`docs/architecture.md`](docs/architecture.md) |
| 開発プロセス（Issue・ADR・AI 活用） | [`docs/development_process.md`](docs/development_process.md) |
| V1 Issue一覧・完了チェック（アーカイブ） | [`docs/archive/v1_issues.md`](docs/archive/v1_issues.md) |
| 画面遷移設計 | [`docs/v1_navigation_songs_recording.md`](docs/v1_navigation_songs_recording.md) |

---

## Author

- **GitHub**: [@omomi-moti](https://github.com/omomi-moti)
