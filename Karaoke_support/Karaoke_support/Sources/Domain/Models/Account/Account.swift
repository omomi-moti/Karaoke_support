#if DEBUG || BETA
import Foundation

/// サーバーのアカウント。Apple のユーザー ID は持たない（ADR 0054）。
struct Account: Equatable, Sendable {
	let id: String
	let createdAt: Date
}
#endif
