# 0064. Beta の構成は Release を写して xcconfig と専用のスキームで作り、Privacy Manifest は構成ごとに外して差し替える

- 2026-11-17 ／ 承認
- 背景：ADR 0053 の 2-A で、TestFlight には Release を写した Beta のビルドで配り、`BETA` の印でアカウントとバックアップを出し分けると決めた。コードは `#if DEBUG || BETA` で書いてあるが、Xcode の構成は Debug と Release しかなく、今アーカイブするとどちらも入らない（#169）。あわせて、Issue 3 で作ったバックアップ用の Privacy Manifest（`Config/PrivacyInfo-Beta.xcprivacy`）はアプリのフォルダの外にあり、どのビルドにも入っていない。アプリのフォルダは同期フォルダなので、中のファイルは構成を問わず全部入る。ADR 0055 の見直す条件の「Beta のビルド設定を作るとき（つなぎ先の渡し方）」もここで決める

## 比較した案

1. Beta だけの設定（`BETA` の印とつなぎ先）の置き場所
- A. `Config/Beta.xcconfig` を作り、`Local.xcconfig` の読み込みと `BETA` の印を書く。アプリの Beta の土台にする
- B. `BETA` の印は `DEBUG` と同じく pbxproj に書き、土台は今の `Debug.xcconfig` を Beta でも使う

2. Privacy Manifest の差し替え方
- A. 2 つの Manifest をアプリのフォルダの中に、同じ名前で別のフォルダに置き、構成ごとに `EXCLUDED_SOURCE_FILE_NAMES` で一方を外す
- B. 今の Manifest をどの構成にも入れ、Beta のときだけ Run Script でアプリの中の Manifest を上書きする
- C. 1 つにまとめ、Release にもバックアップの分を書く

3. Beta でアーカイブする方法
- A. Run・Profile・Archive を Beta にした共有スキーム `Karaoke_support-Beta` を足す
- B. 今のスキームの Archive の構成を、上げるたびに Beta と Release で切り替える
- C. スキームは足さず、`xcodebuild archive -configuration Beta` で上げる

## トレードオフ

- 1-A は、Beta が Release と何が違うかを 1 つのファイルで読める。代わりに、`DEBUG` は pbxproj、`BETA` は xcconfig と、印の置き場所がそろわない。1-B はファイルが増えないが、Beta が `Debug.xcconfig` を読むという名前と中身のずれができる。名前を変えるなら ADR 0055 の決めたことを置き換える
- 2-A は Xcode の仕組みだけで済み、どの構成にどちらが入るかを pbxproj で並べて読める。外すパターンにパスを書くので、フォルダの名前を変えると効かなくなる（ビルドは通り、両方が入って「同じ名前のファイルを 2 つ作る」エラーになるか、一方が抜ける）。`EXCLUDED_SOURCE_FILE_NAMES` はターゲットの設定に `.gitkeep` があり、xcconfig に書くとそれに負けるので、xcconfig には置けない。2-B はスクリプトのサンドボックス（`ENABLE_USER_SCRIPT_SANDBOXING`）で入出力のファイルを書く必要があり、出力が Resources の出力と重なってビルドが止まる。2-C は手間がないが、Release（App Store）が集めていないもの（ユーザー ID と記録）を集めると申告することになる。憲法 II はアプリ内の表示をビルドで分けて正しく書くと決めており（ADR 0053 の 4-A）、Manifest だけ正しくない形になる
- 3-A はスキームを選ぶだけで Beta になり、上げるたびに設定を触らない。スキームが 2 つになり、どちらで上げたかを間違えると、Release を TestFlight に、Beta を App Store に上げうる。3-B は数が増えないが、戻し忘れると次の App Store の提出が Beta になる。3-C はファイルが増えないが、Xcode の Organizer から上げる今の手順と分かれる
- つなぎ先は 1 のどちらでも、本人の Mac の `Local.xcconfig` からアーカイブのときに入る。`Local.xcconfig` がない Mac で Beta をアーカイブすると、ビルドは通り、アカウントの欄が出ないアプリができる。これは仕組みでは止めず、TestFlight に上げる手順（#171）で確かめる

## 選んだ理由

- 1 は A。App Store に出すのは Release、外部テスターに配るのは Beta と分けて考えたい。Beta だけの違いを 1 つのファイルに書いておけば、何を足したビルドなのかが分かる
- 2 は A。Xcode の仕組みだけで差し替えられ、どの構成にどちらが入るかを 1 か所で読める。Release に集めていないものを申告しないことは譲れない
- 3 は A。アーカイブのたびに設定を切り替える形は、戻し忘れで Beta を App Store に出しうる。ADR 0053 の見直す条件にも「出しそうになったとき」がある。スキームを選ぶ形のほうが間違えにくい

## 決めたこと

- プロジェクトと 3 つのターゲットに、Release を写した Beta の構成を足す。アプリの Beta は `Config/Beta.xcconfig` を土台にし、entitlements は Debug と同じもの（Sign in with Apple）にする。ビルド番号は Release と同じ値を写し、この Issue では上げない
- `Config/Beta.xcconfig` には、`#include? "Local.xcconfig"` と `SWIFT_ACTIVE_COMPILATION_CONDITIONS = BETA $(inherited)` だけを書く
- バックアップ用の Manifest は `Karaoke_support/Beta/PrivacyInfo.xcprivacy` に移す。Release は `*/Beta/PrivacyInfo.xcprivacy` を外し、今の空の Manifest を入れる。Debug と Beta は `*/Karaoke_support/PrivacyInfo.xcprivacy` を外し、バックアップ用を入れる（Debug にもアカウントの機能があるので、Beta にそろえる）
- 共有スキーム `Karaoke_support-Beta` を足し、Run・Profile・Archive を Beta にする。Test と Analyze は今のスキームと同じく Debug。今のスキーム `Karaoke_support` は Archive が Release のまま
- プライバシーポリシーの行は `PrivacyPolicyLinkView` にまとめ、全部のビルドの設定の「データについて」の欄と、同意の画面で使う（審査ガイドライン 5.1.1）

## 見直す条件

- Beta のビルドを App Store の審査に出してしまったとき、または出しそうになったとき（スキームの名前やアーカイブの手順を、仕組みで止める形にする）
- `Local.xcconfig` がないまま Beta を上げてしまったとき（ビルドで止める）
- アプリのフォルダの構成を変え、Manifest を外すパターンが効かなくなりうるとき
- App Store にアカウントとバックアップを出す準備を始めるとき（Beta と Release を 1 つに戻すか）

関連：#169、[0053](0053-beta-testers-and-auto-backup.md)、[0055](0055-local-api-base-url-and-optional-account.md)、[backend_design.md](../backend_design.md)、[憲法](../constitution.md) II
