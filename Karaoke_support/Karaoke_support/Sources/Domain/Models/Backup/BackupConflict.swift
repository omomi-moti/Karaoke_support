#if DEBUG || BETA
import Foundation

/// サーバーの控えが、この端末が最後に送った版でなかったときに、確かめてもらう中身（FR-4、ADR 0058）。
/// 「サーバーの N 件を、この端末の M 件で置き換えます」に使う。
struct BackupConflict: Equatable, Sendable {
	/// 確かめたときのサーバーの版。控えがなくなっていたら nil。置き換えるときの条件に使う。
	let serverRevision: Int?
	/// サーバーの控えの記録の件数。控えがなくなっていたら 0。
	let serverSessionCount: Int
	/// この端末の記録の件数。
	let localSessionCount: Int
}
#endif
