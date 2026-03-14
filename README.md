# ヒトカラモバイルiOS

ヒトカラ（一人カラオケ）の歌唱セッションを記録・振り返るためのiOSアプリです。

---

## 開発環境要件

| 項目 | バージョン |
|------|-----------|
| **Xcode** | **16.0 以上**（本プロジェクトは Xcode 16 で生成） |
| **Swift** | 5.9 以上 |
| **iOS Deployment Target** | 17.0 以上 |
| **対応デバイス** | iPhone のみ |

> **注意**: `project.pbxproj` は `objectVersion = 77` および `PBXFileSystemSynchronizedRootGroup` を使用しています。これらは Xcode 16 で導入された形式であるため、**Xcode 15 以前では開けません**。互換性が必要になった場合はプロジェクトを再生成して移行してください。

---

## セットアップ

1. Xcode 16 以上をインストール
2. リポジトリをクローン
3. `Karaoke_support/Karaoke_support.xcodeproj` を Xcode で開く
4. ターゲットデバイスを選択してビルド・実行

---

## プロジェクト構成

```
Sources/
├── App/          # @main エントリポイント・ルート DI
├── Presentation/ # SwiftUI Views・ViewModels
├── Domain/       # Models・Repository プロトコル
└── Data/         # SwiftData・Spotify API・キャッシュ実装
```


