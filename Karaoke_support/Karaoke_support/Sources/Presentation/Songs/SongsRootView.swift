import SwiftUI

struct SongsRootView: View {
	let onSavedMoveToHistory: () -> Void
	@Binding var manualRecordingNavigationTick: Int

	@Environment(\.insightRepository) private var insightRepository
	@Environment(\.sessionRepository) private var sessionRepository
	@Environment(\.navigateToManualRecording) private var navigateToManualRecording

	private enum Segment: String, CaseIterable, Identifiable {
		case intent = "インテント"
		case spotify = "Spotify"

		var id: String { rawValue }
	}

	@State private var segment: Segment = .intent
	@State private var path = NavigationPath()

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
						IntentTabContainerView(
							insightRepository: insightRepository,
							sessionRepository: sessionRepository,
							onSelectTrack: { selected in
								path.append(SongsRecordingRoute.recording(selected))
							},
							onNavigateToManualRecording: navigateToManualRecording
						)
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
			.onChange(of: manualRecordingNavigationTick) { _, newValue in
				guard newValue > 0 else { return }
				path = NavigationPath()
				path.append(SongsRecordingRoute.manualRecording)
			}
		}
	}

	private func handleRecordingSaved() {
		path = NavigationPath()
		onSavedMoveToHistory()
	}
}

#Preview {
	SongsRootView(onSavedMoveToHistory: {}, manualRecordingNavigationTick: .constant(0))
		.environment(\.insightRepository, PreviewInsightRepository())
		.environment(\.sessionRepository, PreviewSessionRepository())
		.environment(\.navigateToManualRecording) {}
}
