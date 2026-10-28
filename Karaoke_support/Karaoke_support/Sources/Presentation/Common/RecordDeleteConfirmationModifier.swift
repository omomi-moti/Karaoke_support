import SwiftUI

/// 記録を消す前に確認を出す（#133）。`pendingSessionId` に値が入ると確認を出し、「削除」を押したときだけ `onDelete` を呼ぶ。
struct RecordDeleteConfirmationModifier: ViewModifier {
	@Binding var pendingSessionId: UUID?
	let onDelete: (UUID) -> Void

	func body(content: Content) -> some View {
		content.alert(
			"この記録を削除しますか？",
			isPresented: Binding(
				get: { pendingSessionId != nil },
				set: { if !$0 { pendingSessionId = nil } }
			),
			presenting: pendingSessionId
		) { sessionId in
			Button("削除", role: .destructive) {
				onDelete(sessionId)
			}
			Button("キャンセル", role: .cancel) {}
		} message: { _ in
			Text("削除すると元に戻せません。")
		}
	}
}

extension View {
	func recordDeleteConfirmation(pendingSessionId: Binding<UUID?>, onDelete: @escaping (UUID) -> Void) -> some View {
		modifier(RecordDeleteConfirmationModifier(pendingSessionId: pendingSessionId, onDelete: onDelete))
	}
}
