import SwiftUI

struct SongsRootView: View {
	let onSavedMoveToHistory: () -> Void

	private enum Segment: String, CaseIterable, Identifiable {
		case intent = "インテント"
		case spotify = "Spotify"

		var id: String { rawValue }
	}

	@State private var segment: Segment = .intent
	@State private var path = NavigationPath()

	/// ランキングタップのスタブ用（I-013）。固定リテラルは trim 後も非空のため ``SelectedTrack`` は必ず成功。
	private static let stubRankingSample = SelectedTrack(
		spotifyTrackId: nil,
		userEnteredName: "サンプル曲（ランキングスタブ）"
	)!

	var body: some View {
		NavigationStack(path: $path) {
			VStack(spacing: 16) {
				Picker("選曲タブ", selection: $segment) {
					ForEach(Segment.allCases) { segment in
						Text(segment.rawValue).tag(segment)
					}
				}
				.pickerStyle(.segmented)
				.padding(.horizontal)

				Group {
					switch segment {
					case .intent:
						VStack(spacing: 20) {
							EmptyPlaceholderView(
								title: "インテント（準備中）",
								message: "タイムマシン・マイアンセムは I-017 以降で表示します。下から選曲済みの曲で記録フローを試せます。"
							)
							/// ランキングタップのスタブ（I-013）。I-018 で本番リストに差し替え。
							Button {
								path.append(SongsRecordingRoute.recording(Self.stubRankingSample))
							} label: {
								Label("選曲済みとして記録へ（スタブ）", systemImage: "music.note.list")
							}
							.buttonStyle(.borderedProminent)
							.tint(.pink.opacity(0.85))
						}
					case .spotify:
						EmptyPlaceholderView(
							title: "Spotify視聴履歴（準備中）",
							message: "V1ではプレースホルダー表示です。"
						)
					}
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
			.navigationTitle("選曲")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						path.append(SongsRecordingRoute.manualRecording)
					} label: {
						Label("記録を追加", systemImage: "plus")
					}
				}
			}
			.navigationDestination(for: SongsRecordingRoute.self) { route in
				switch route {
				case .manualRecording:
					RecordingSheetContainerView(
						seed: .mode(.manual),
						presentation: .navigationStack,
						onSavedMoveToHistory: { handleRecordingSaved() }
					)
				case .recording(let selectedTrack):
					RecordingSheetContainerView(
						seed: .selectedTrack(selectedTrack),
						presentation: .navigationStack,
						onSavedMoveToHistory: { handleRecordingSaved() }
					)
				}
			}
		}
	}

	private func handleRecordingSaved() {
		path = NavigationPath()
		onSavedMoveToHistory()
	}
}

#Preview {
	SongsRootView(onSavedMoveToHistory: {})
}
