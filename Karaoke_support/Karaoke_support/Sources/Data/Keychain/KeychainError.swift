#if DEBUG || BETA
import Foundation

/// Keychain の操作が失敗したときの `OSStatus`。
struct KeychainError: Error, Equatable {
	let status: OSStatus
}
#endif
