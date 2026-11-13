#if DEBUG || BETA
import Foundation
import Testing

@testable import Karaoke_support

@Suite("UserDefaultsBackupStateStore")
@MainActor
struct UserDefaultsBackupStateStoreTests {
	/// テストごとに別の置き場を使い、終わったら消す。
	private func withStore(_ body: (UserDefaultsBackupStateStore, UserDefaults) throws -> Void) rethrows {
		let suiteName = "UserDefaultsBackupStateStoreTests.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		try body(UserDefaultsBackupStateStore(defaults: defaults), defaults)
	}

	@Test("初めはオフで、ほかは空")
	func startsEmpty() {
		withStore { store, _ in
			#expect(!store.isEnabled)
			#expect(store.consentVersion == nil)
			#expect(store.lastRevision == nil)
			#expect(store.lastSucceededAt == nil)
			#expect(store.lastFailure == nil)
		}
	}

	@Test("置いた値を読み直せる")
	func roundTrip() {
		withStore { store, defaults in
			let date = Date(timeIntervalSince1970: 1_794_531_723.5)
			store.isEnabled = true
			store.consentVersion = 1
			store.lastRevision = 12
			store.lastSucceededAt = date
			store.lastFailure = .needsConfirmation

			let reopened = UserDefaultsBackupStateStore(defaults: defaults)
			#expect(reopened.isEnabled)
			#expect(reopened.consentVersion == 1)
			#expect(reopened.lastRevision == 12)
			#expect(reopened.lastSucceededAt == date)
			#expect(reopened.lastFailure == .needsConfirmation)

			store.lastFailure = nil
			#expect(reopened.lastFailure == nil)
		}
	}

	@Test("消すと 5 つとも空になり、ほかの値には触らない")
	func clearRemovesOnlyBackupKeys() {
		withStore { store, defaults in
			defaults.set("keep", forKey: "other")
			store.isEnabled = true
			store.consentVersion = 1
			store.lastRevision = 3
			store.lastSucceededAt = Date()
			store.lastFailure = .unreachable

			store.clear()

			#expect(!store.isEnabled)
			#expect(store.consentVersion == nil)
			#expect(store.lastRevision == nil)
			#expect(store.lastSucceededAt == nil)
			#expect(store.lastFailure == nil)
			#expect(defaults.string(forKey: "other") == "keep")
			#expect(defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("backup.") }.isEmpty)
		}
	}

	@Test("知らない失敗の理由は、空として読む")
	func unknownFailureReadsAsNil() {
		withStore { store, defaults in
			defaults.set("somethingNew", forKey: "backup.lastFailure")
			#expect(store.lastFailure == nil)
		}
	}
}
#endif
