import Foundation

/// 記録をどこから付けたか（ドメインでは enum、永続化時は RawValue で扱う）。#120
enum RecordSource: String, Codable, CaseIterable, Sendable {
	/// ＋・検索などから、自分で曲を選んで付けた記録
	case manual
	/// 保存直後のシートの提案のカードから開き、その曲のまま付けた記録
	case suggestion
	/// 選曲画面のカードから開き、その曲のまま付けた記録（#126）
	case selectionScreen
}
