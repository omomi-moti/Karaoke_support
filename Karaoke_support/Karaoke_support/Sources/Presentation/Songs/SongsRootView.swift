import SwiftUI

struct SongsRootView: View {
    let onSelectTrack: (SelectedTrack) -> Void

    @Environment(\.insightRepository) private var insightRepository
    @Environment(\.sessionRepository) private var sessionRepository
    @Environment(\.navigateToManualRecording) private var navigateToManualRecording

    private enum Segment: String, CaseIterable, Identifiable {
        case intent = "インテント"
        case spotify = "Spotify"

        var id: String { rawValue }
    }

    @State private var segment: Segment = .intent

    var body: some View {
        NavigationStack {
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
                            onSelectTrack: onSelectTrack,
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
            .appBackgroundGradient()
            .navigationTitle("選曲")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SongsRootView(onSelectTrack: { _ in })
        .environment(\.insightRepository, PreviewInsightRepository())
        .environment(\.sessionRepository, PreviewSessionRepository())
        .environment(\.navigateToManualRecording) {}
}
