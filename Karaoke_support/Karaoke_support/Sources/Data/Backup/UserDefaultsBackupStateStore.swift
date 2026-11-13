#if DEBUG || BETA
import Foundation

/// バックアップの状態を `UserDefaults` に置く（ADR 0058 の 6-A）。
/// 置くのは、読まれても書き換えられても害のない 5 つだけ。トークンは Keychain、記録は SwiftData のまま。
@MainActor
final class UserDefaultsBackupStateStore: BackupStateStoring {
	private enum Key {
		static let isEnabled = "backup.isEnabled"
		static let consentVersion = "backup.consentVersion"
		static let lastRevision = "backup.lastRevision"
		static let lastSucceededAt = "backup.lastSucceededAt"
		static let lastFailure = "backup.lastFailure"
		static let all = [isEnabled, consentVersion, lastRevision, lastSucceededAt, lastFailure]
	}

	private let defaults: UserDefaults
	private(set) var clearCount = 0

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	var isEnabled: Bool {
		get { defaults.bool(forKey: Key.isEnabled) }
		set { defaults.set(newValue, forKey: Key.isEnabled) }
	}

	var consentVersion: Int? {
		get { defaults.object(forKey: Key.consentVersion) as? Int }
		set { set(newValue, forKey: Key.consentVersion) }
	}

	var lastRevision: Int? {
		get { defaults.object(forKey: Key.lastRevision) as? Int }
		set { set(newValue, forKey: Key.lastRevision) }
	}

	var lastSucceededAt: Date? {
		get { defaults.object(forKey: Key.lastSucceededAt) as? Date }
		set { set(newValue, forKey: Key.lastSucceededAt) }
	}

	var lastFailure: BackupFailure? {
		get { defaults.string(forKey: Key.lastFailure).flatMap(BackupFailure.init(rawValue:)) }
		set { set(newValue?.rawValue, forKey: Key.lastFailure) }
	}

	func clear() {
		for key in Key.all {
			defaults.removeObject(forKey: key)
		}
		clearCount += 1
	}

	private func set(_ value: Any?, forKey key: String) {
		if let value {
			defaults.set(value, forKey: key)
		} else {
			defaults.removeObject(forKey: key)
		}
	}
}
#endif
