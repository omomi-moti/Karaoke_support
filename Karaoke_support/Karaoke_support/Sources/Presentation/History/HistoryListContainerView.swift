import SwiftUI

/// `@Environment` で渡る `sessionRepository` から **初回描画時点で** ``HistoryViewModel`` を生成する。
/// `HistoryRootView` で `onAppear` まで遅延すると `Color.clear` 1 フレームが出うるため分離する。
///
/// 履歴→曲詳細（行タップ・I-019）を ``HistoryRoute`` で開く。編集（リードスワイプ）は `RootView` の記録シートで開く。
struct HistoryListContainerView: View {
	private let sessionRepository: any SessionRepositoryProtocol
	@Environment(\.trackRepository) private var trackRepository
	@State private var viewModel: HistoryViewModel
	/// 画面の積み方は `RootView` が持つ。＋で、曲詳細を開いているかを読むため（ADR 0047）。
	@Binding private var navigationPath: [HistoryRoute]

	init(sessionRepository: any SessionRepositoryProtocol, navigationPath: Binding<[HistoryRoute]>) {
		self.sessionRepository = sessionRepository
		_navigationPath = navigationPath
		_viewModel = State(initialValue: HistoryViewModel(sessionRepository: sessionRepository))
	}

	var body: some View {
		NavigationStack(path: $navigationPath) {
			HistoryListView(viewModel: viewModel, navigationPath: $navigationPath)
				.navigationDestination(for: HistoryRoute.self) { route in
					switch route {
					case .trackDetail(let trackId, let title, let artistName):
						TrackDetailContainerView(
							sessionRepository: sessionRepository,
							trackRepository: trackRepository,
							trackId: trackId,
							trackTitle: title,
							trackArtistName: artistName
						) { newTrackId, newArtistName in
							replaceLastRoute(with: .trackDetail(trackId: newTrackId, title: title, artistName: newArtistName))
						}
					}
				}
		}
	}

	/// 曲詳細で歌手名を直したとき、行き先の値も今の曲に合わせる。＋で開く記録シートがこの値を読むため（ADR 0047）。
	/// 行き先が変わると画面が作り直されるので、積み直しのアニメーションは出さない。
	private func replaceLastRoute(with route: HistoryRoute) {
		guard let lastIndex = navigationPath.indices.last else { return }
		var transaction = Transaction()
		transaction.disablesAnimations = true
		withTransaction(transaction) {
			navigationPath[lastIndex] = route
		}
	}
}

#Preview {
	HistoryListContainerView(sessionRepository: PreviewSessionRepository(), navigationPath: .constant([]))
		.environment(\.navigateToManualRecording) {}
}
