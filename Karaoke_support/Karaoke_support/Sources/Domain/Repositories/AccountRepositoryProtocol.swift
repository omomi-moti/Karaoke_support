#if DEBUG || BETA
import Foundation

/// サーバーのアカウントを扱う Repository のプロトコル（#152）。
/// `@MainActor` の実装はもともと Sendable なので、Sendable を契約に入れて `any` 越しにも安全に共有できるようにする（ADR 0027）。
@MainActor
protocol AccountRepositoryProtocol: Sendable {
	/// 端末にサーバーのトークンがあるか。サーバーには問い合わせない。
	var isSignedIn: Bool { get }

	/// Apple のトークンと nonce の元の値をサーバーに渡し、受け取ったサーバーのトークンを端末に保存する。
	/// 失敗したときは ``AccountRepositoryError`` を投げる。
	func signInWithApple(identityToken: String, rawNonce: String) async throws

	/// サインインしている自分のアカウントを読む。トークンがなければ ``AccountRepositoryError/unauthorized`` を投げる。
	/// サーバーがトークンを受け付けなかったときは、端末のトークンも消してから投げる。
	func fetchMe() async throws -> Account

	/// サーバーにこの端末のトークンを消すよう頼み、端末のトークンも消す。
	/// サーバーに届かない・失敗したときも端末のトークンは消し、エラーにしない。
	/// 端末のトークンを消せなかったときだけ ``AccountRepositoryError/tokenStorage`` を投げる。
	func signOut() async throws
}
#endif
