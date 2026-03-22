import Foundation

/// 履歴一覧と ``SessionRepositoryProtocol/fetchByIntent`` が共有する「直近セッション」の件数上限。
///
/// **意味**: 全期間の Intent 別一覧ではなく、日時降順で見た **直近 N 件のウィンドウ**内で Intent が一致するものだけを返す（UI・Repository でズレないようにする）。
/// I-015 のページネーション導入時は、ここと ``HistoryViewModel`` の読み込みを合わせて更新する。
enum SessionRecentWindow {
	static let maxSessionCount = 200
}
