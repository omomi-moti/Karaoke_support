---
paths:
  - "Karaoke_support/Karaoke_supportTests/**"
  - "Karaoke_support/Karaoke_supportUITests/**"
---

# テスト

- 新しいテストは Swift Testing（`@Suite` / `@Test` / `#expect`）で書く。前からある XCTest のファイルは、ほかの理由で触るとき以外は書き換えない。
- SwiftData を触るテストは、本物の `ModelContainer(isStoredInMemoryOnly: true)` を使う。DB の層はモックにしない。
- ViewModel のテストは、プロトコルを通してモックの Repository を注入する。モックはテストのファイルごとに `private` で持つ。
- Repository のプロトコルにメソッドを足したら、それに準拠するモックを全部直す（テストのターゲットで `: SessionRepositoryProtocol` などを探す）。
- UI テストのターゲットは、`KARAOKE_UITEST_IN_MEMORY=1` で起動できることだけを確かめている。

並びはアプリに合わせる：`App/`、`Data/SwiftData/`、`Domain/`、`Presentation/{機能}/`。
