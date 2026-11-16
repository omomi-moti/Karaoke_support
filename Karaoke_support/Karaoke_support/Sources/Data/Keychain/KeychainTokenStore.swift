#if DEBUG || BETA
import Foundation
import Security

/// サーバーのトークンを Keychain に置く。
/// 端末のロックを最初に解いた後だけ読め、バックアップや別の端末には移らない（`AfterFirstUnlockThisDeviceOnly`、ADR 0054）。
struct KeychainTokenStore: ServerTokenStoring {
	private let service: String
	private let account = "server-token"

	/// - Parameter service: Keychain の項目を見分ける名前。テストでは別の名前にして、本物のトークンに触れない。
	init(service: String = "com.omomimoti.hitokaralog.server-token") {
		self.service = service
	}

	func read() throws -> String? {
		var query = baseQuery
		query[kSecReturnData as String] = true
		query[kSecMatchLimit as String] = kSecMatchLimitOne

		var item: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &item)
		if status == errSecItemNotFound {
			return nil
		}
		guard status == errSecSuccess, let data = item as? Data else {
			throw KeychainError(status: status)
		}
		return String(decoding: data, as: UTF8.self)
	}

	/// すでにあれば書き換え、なければ足す。失敗したときは前の値が残る。
	func save(_ token: String) throws {
		let attributes: [String: Any] = [
			kSecValueData as String: Data(token.utf8),
			kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
		]
		let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
		if status == errSecItemNotFound {
			let added = SecItemAdd(baseQuery.merging(attributes) { $1 } as CFDictionary, nil)
			guard added == errSecSuccess else {
				throw KeychainError(status: added)
			}
			return
		}
		guard status == errSecSuccess else {
			throw KeychainError(status: status)
		}
	}

	func delete() throws {
		let status = SecItemDelete(baseQuery as CFDictionary)
		guard status == errSecSuccess || status == errSecItemNotFound else {
			throw KeychainError(status: status)
		}
	}

	private var baseQuery: [String: Any] {
		[
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account,
		]
	}
}
#endif
