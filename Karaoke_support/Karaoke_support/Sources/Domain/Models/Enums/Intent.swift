import Foundation

/// 歌唱の意図（ドメインでは enum、永続化時は RawValue で扱う）
enum Intent: String, Codable, CaseIterable {
	case shout
	case emo
	case practice
}

