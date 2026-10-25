import SwiftUI

/// ``SettingsViewModel`` を作り、設定の中身を出す。
/// 「テストへのご協力」の欄は仮説を確かめるためのもので、App Store に出す前に消す（ADR 0034）。
struct SettingsContainerView: View {
	@State private var viewModel: SettingsViewModel

	init(insightRepository: any InsightRepositoryProtocol) {
		_viewModel = State(initialValue: SettingsViewModel(insightRepository: insightRepository))
	}

	var body: some View {
		List {
			Section {
				LabeledContent("提案から記録した数") {
					Text(countsText)
						.monospacedDigit()
				}
			} header: {
				Text("テストへのご協力")
			} footer: {
				Text("記録したあとに出る「次はこの曲？」から付けた記録の数です。右は、この数を数え始めてから付けた記録の数です。この画面のスクリーンショットを、TestFlight のフィードバックから送ってください。")
			}

			if let message = viewModel.loadErrorMessage {
				Section {
					InlineErrorRetryView(message: message, retryTitle: "再試行") {
						Task { await viewModel.load() }
					}
					.listRowInsets(EdgeInsets())
					.listRowBackground(Color.clear)
				}
			}
		}
		.scrollContentBackground(.hidden)
		// タブを開くたびに読み直す（ほかのタブで記録したぶんを出す）
		.task {
			await viewModel.load()
		}
	}

	private var countsText: String {
		guard let counts = viewModel.recordSourceCounts else { return "—" }
		return "\(counts.suggestion) ／ \(counts.recorded)"
	}
}

#Preview {
	SettingsContainerView(insightRepository: PreviewInsightRepository())
}
