#if DEBUG || BETA
import SwiftUI
import UIKit

/// アプリが裏に回ったとき・前に戻ったときに、バックアップを送るきっかけ（#161、ADR 0058・0059）。
/// 送ってよいかは Repository が決め、ここはきっかけを渡すだけ。自動のときの失敗は画面に出さない。
/// 裏に回ったときは、送り終えるか時間切れになるまで、`beginBackgroundTask` で時間をもらう。
@MainActor
@Observable
final class BackgroundBackupTrigger {
	typealias BeginBackgroundTask = @MainActor (@escaping @MainActor @Sendable () -> Void) -> UIBackgroundTaskIdentifier
	typealias EndBackgroundTask = @MainActor (UIBackgroundTaskIdentifier) -> Void

	@ObservationIgnored private let backupRepository: any BackupRepositoryProtocol
	@ObservationIgnored private let beginBackgroundTask: BeginBackgroundTask
	@ObservationIgnored private let endBackgroundTask: EndBackgroundTask
	/// 終わっていない裏の時間。時間切れと送り終えたときの両方から終わらせるので、終わらせたら外して 2 回呼ばない。
	@ObservationIgnored private var backgroundTasks: [Int: UIBackgroundTaskIdentifier] = [:]
	@ObservationIgnored private var nextBackgroundTaskKey = 0

	/// 送る処理が終わるたびに増える。設定のバックアップの欄は、この変化で状態を読み直す。
	private(set) var completedCount = 0

	init(
		backupRepository: any BackupRepositoryProtocol,
		beginBackgroundTask: @escaping BeginBackgroundTask = { UIApplication.shared.beginBackgroundTask(withName: "Backup", expirationHandler: $0) },
		endBackgroundTask: @escaping EndBackgroundTask = { UIApplication.shared.endBackgroundTask($0) }
	) {
		self.backupRepository = backupRepository
		self.beginBackgroundTask = beginBackgroundTask
		self.endBackgroundTask = endBackgroundTask
	}

	func handle(_ phase: ScenePhase) {
		switch phase {
		case .background:
			backUpInBackground()
		case .active:
			Task { await backUp(trigger: .foreground) }
		default:
			break
		}
	}

	private func backUpInBackground() {
		nextBackgroundTaskKey += 1
		let key = nextBackgroundTaskKey
		let identifier = beginBackgroundTask { [weak self] in
			self?.finishBackgroundTask(for: key)
		}
		if identifier != .invalid {
			backgroundTasks[key] = identifier
		}
		Task {
			await backUp(trigger: .background)
			finishBackgroundTask(for: key)
		}
	}

	private func backUp(trigger: BackupTrigger) async {
		_ = try? await backupRepository.backUp(trigger: trigger)
		completedCount += 1
	}

	private func finishBackgroundTask(for key: Int) {
		guard let identifier = backgroundTasks.removeValue(forKey: key) else { return }
		endBackgroundTask(identifier)
	}
}
#endif
