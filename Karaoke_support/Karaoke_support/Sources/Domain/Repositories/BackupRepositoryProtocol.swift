#if DEBUG || BETA
import Foundation

/// 記録のバックアップを扱う Repository のプロトコル（#161、ADR 0058）。
/// 送る処理はここにまとめ、きっかけ（裏に回った・前に戻った・ボタン）は呼ぶ側が決める。
/// 「ほかの端末の控えを自動で上書きしない」はここで守る。どこから呼ばれても守るため（docs/backend_design.md の「責任の分け方」）。
/// 失敗は ``BackupFailure`` を投げる。
@MainActor
protocol BackupRepositoryProtocol: Sendable {
	/// 端末に置いたバックアップの状態。サーバーには問い合わせない。
	var status: BackupStatus { get }

	/// 同意してオンにし、そのまま 1 回送る。
	func enable() async throws -> BackupOutcome

	/// きっかけに合わせて、送ってよければ全件を送る。同時には 1 つしか送らない。
	/// 送っている途中に呼ばれたら後ろに 1 つだけ予約し（何回呼ばれても 1 つにまとめ、きっかけは強いほうにそろえる）、
	/// 番が来たら記録を読み直す。途中で記録が変わっても、最後には最新の記録が届くようにするため。
	/// オフ・記録が 0 件・前回と同じ中身・412 の後の自動のときは送らない。
	/// 前回と同じ中身で送らないときは、サーバーに届いているので、「確認が要る」以外の最後の失敗を消す。
	/// 412 のときは状態を「確認が要る」にして ``BackupFailure/needsConfirmation`` を投げる。
	/// 401 のときは端末のトークンとバックアップの状態を消して ``BackupFailure/signInRequired`` を投げる。
	func backUp(trigger: BackupTrigger) async throws -> BackupOutcome

	/// 412 の後に、確かめてもらう件数と、そのときのサーバーの版を読む。
	func fetchConflict() async throws -> BackupConflict

	/// 本人が確かめた後で、そのとき読んだ版を条件にして、サーバーの控えをこの端末の全件で置き換える。
	/// その間にサーバーの版が変わっていたら、もう一度 ``BackupFailure/needsConfirmation`` を投げる。
	func replaceRemote(confirmed conflict: BackupConflict) async throws -> BackupOutcome

	/// オフにする前の確認に出す、サーバーの控えの記録の件数。控えがなければ nil。
	func fetchRemoteSessionCount() async throws -> Int?

	/// 端末ではすぐにオフにし、送っている途中の送信が終わってから、サーバーの控えを消す。消せたら端末の状態も消す。
	/// 消せなかったら状態を「消せなかった」にして ``BackupFailure/remoteDeletionFailed`` を投げる。
	/// 消す前・消している間に ``enable()`` でオンに戻されたら、オンの状態は消さない。
	/// 消す前にサインアウトなどで状態が消されたら、サーバーの控えは消さない（別のアカウントの控えを消さないため）。
	func disable() async throws

	/// オフにしたときに消せなかったサーバーの控えを、もう一度消す。
	func retryRemoteDeletion() async throws

	/// 端末に曲も記録もなく、サーバーに控えがあるときだけ、取り込める控えの件数と日時を返す（FR-5、ADR 0061）。
	/// 端末に曲か記録があれば、サーバーには問い合わせずに nil を返す。控えがなければ nil。
	/// 失敗は ``BackupRestoreFailure`` を投げる。401 のときは端末のトークンとバックアップの状態を消す。
	func fetchRestorableBackup() async throws -> BackupRestorableSummary?

	/// サーバーの控えを、空の端末に全部取り込み、取り込んだ記録の件数を返す（ADR 0061）。
	/// 値を全部確かめてから 1 回だけ保存する。1 件でもおかしい・途中で失敗したときは何も書かない。端末に曲か記録があれば書かない。
	/// 取り込めたら控えの版を覚え、その後に送るときに 412 にならないようにする。バックアップのオン・オフは変えない。
	/// 送信・削除と同じく前の処理が終わってから動き、途中でサインアウトされたら何も書かない。
	/// 失敗は ``BackupRestoreFailure`` を投げる。
	func restoreAll() async throws -> Int
}
#endif
