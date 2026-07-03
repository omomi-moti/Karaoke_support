# feature/i-014d-history-loading-indicator 実装ログ

**日付**: 2026-07-04
**対象**: [I-014-D] 履歴一覧のフィルター/リロード中にローディング表示が出ない（GitHub Issue #85）

---

## 概要

履歴タブを表示するたびに、一覧が一瞬スピナーや Empty State（「まず1曲歌ってみよう！」）に置き換わって見える「カットイン」表示を解消した。

当初の Issue は「再読込中にローディング表示が出ない」だったが、調査の結果、真の問題は **ローディング表示の欠如ではなく、再読込のたびに一覧そのものが消えること**（`sessions` の即時クリア）と、**初回描画の1フレームに Empty State が挟まること**（`isLoading` 初期値）の2点であることが判明した。

---

## 対応の流れ

1. **Issue の起票**: 履歴一覧のロード中表示について調査し、初回ロード用 `ProgressView` の条件が `isLoading && sessions.isEmpty` のため、既存行がある状態の再読込ではインジケータが出ないことを確認。`[I-014-D]` として Issue #85 を起票（I-014 の分岐タスク A/B/C の続番）。
2. **View にオーバーレイを追加（第1弾）**: `HistoryListView` の `List` に `.overlay { if isLoading { 半透明フィル + ProgressView } }` / `.allowsHitTesting(!isLoading)` / フェードアニメーションを追加。
3. **「一瞬何かが出る」報告 → ちらつき対策**: ローカル SwiftData のロードは数十msで終わるため、オーバーレイ自体が点滅として知覚される問題が発生。挿入側のみ 0.2 秒遅延する **非対称トランジション**（`insertion: .opacity.animation(...).delay(0.2)` / `removal: 遅延なし`）に変更し、短時間ロードでは表示されないようにした。
4. **それでもカットインが残る → 根本原因の調査**: `HistoryViewModel` / `HistoryListContainerView` / `RootView` を追跡し、原因が View ではなく ViewModel 側に2つあることを特定。
   - **原因①**: `loadInitial()` が開始直後に `sessions = []` で一覧を空にするため、`.task(id: filter)`（タブ表示のたびに発火）→ `load()` のたびに View の分岐が `isLoading && sessions.isEmpty`（中央スピナー）に切り替わり、一覧が丸ごと消えていた。**第1弾で追加したオーバーレイは一覧分岐に付いているため、一覧分岐自体が描画されない再読込中には一度も表示されていなかった。**
   - **原因②**: `isLoading` の初期値が `false` のため、ViewModel 生成直後・`.task` 発火前の1フレームだけ `sessions.isEmpty` の Empty State 分岐が描画されていた（「曲を追加して」の導線が一瞬見える）。
5. **最小修正の再検討**: 当初案は「`sessions = []` 削除 + `hasLoadedOnce` フラグ追加 + View の条件変更」だったが、`applyInitialPage` が `sessions = sortOrder.sorted(items)` で**配列を丸ごと差し替える**実装であることを確認し、フラグ追加なしの2行変更まで削減できると判断。
6. **ViewModel を2行変更（第2弾・根本対応）**:
   - `isLoading` の初期値を `true` に変更（原因②の解消。生成直後から「初回ロード中」扱い）
   - `loadInitial()` の `sessions = []` を削除（原因①の解消。旧スナップショットを新データ到着まで保持）
7. **実機（シミュレータ）で確認**: タブ切り替え・保存後の自動遷移でカットインが出ないことをユーザーが確認。

---

## 変更ファイル

| ファイル | 変更内容 |
|---|---|
| `Sources/Presentation/History/HistoryViewModel.swift` | `isLoading` の初期値を `true` に変更。`loadInitial()` の `sessions = []` を削除（旧スナップショット保持） |
| `Sources/Presentation/History/List/HistoryListView.swift` | `List` に半透明オーバーレイ + `ProgressView`（挿入側のみ 0.2 秒遅延の非対称トランジション）と `.allowsHitTesting(!isLoading)` を追加 |

---

## 設計判断

### ローディング表示は「一定時間かかったときだけ」出す（非対称トランジション）

短時間で終わるロードにインジケータを出すと、それ自体が点滅・ちらつきとして知覚される。挿入側にのみ `delay(0.2)` を付けた非対称トランジションにより、0.2 秒以内に終わるロード（ローカル SwiftData ではほぼ常時）ではオーバーレイが描画される前に消え、本当に長引いたときだけフェードインする。消える側は遅延なしで即座に消す。

### 再読込中も旧スナップショットを表示し続ける

`loadInitial()` での `sessions = []` クリアを廃止。成功時は `applyInitialPage` が配列を丸ごと差し替えるためクリアは不要で、失敗時は従来どおり `catch` 節が `sessions = []` にするため挙動の穴はない。フィルター切り替え中に前のフィルターの行が見える仕様変更を伴うが、`.allowsHitTesting(false)` で操作はブロック済みのため実害はない。`loadNextPageIfNeeded` も `guard !isLoading` で弾くため、ロード中に旧行の `.task` が発火してもページングは走らない。

### `hasLoadedOnce` フラグは追加しない（`isLoading` 初期値で代替）

初回1フレームの Empty State 対策として当初 `hasLoadedOnce` フラグを検討したが、`isLoading` の初期値を `true` にするだけで View の既存分岐（`isLoading && sessions.isEmpty` → スピナー）が初回フレームから成立するため、フラグ追加も View の条件変更も不要と判断。状態変数を増やさないことを優先した。

### オーバーレイは外側の `ZStack` ではなく `List` に付ける

外側の `ZStack`（背景グラデーション用）に足すとフィルターバー・ソートコントロールまで覆ってしまい、ロード中のフィルター操作ができなくなる。操作ブロックの対象を一覧だけに絞るため、`List` のモディファイアチェーン末尾に `.overlay` を付けた（フィルター連打は `loadGeneration` の世代ガードが捌く）。

---

## テスト・確認

- 自動テストの追加は無し（表示タイミングの変更のため）。既存の `HistoryViewModel` 系テストが `isLoading` 初期値・`loadInitial` のクリア挙動に依存していないかは ⌘U で要確認（ローカルの `xcodebuild` は Command Line Tools 問題で中断したため、Xcode 上での実行を推奨）。
- 手動確認: 履歴タブへの切り替え・曲保存後の自動遷移でカットインが出ないこと、Intent フィルター切り替えで一覧が消えずに更新されること、歌唱0件時の Empty State 表示、スワイプ削除・編集遷移をユーザーが確認済み。

---

## 参照

- Issue 定義: GitHub Issue #85（`[I-014-D] 履歴一覧のフィルター/リロード中にローディング表示が出ない`）
- 関連ドキュメント: `docs/v1_issues.md` I-014 分岐タスク（A/B/C の続番として D）
- 参照トークン: `AppColor.backgroundGradientEnd`（`Sources/Presentation/Theme/AppColor.swift`）

以上。
