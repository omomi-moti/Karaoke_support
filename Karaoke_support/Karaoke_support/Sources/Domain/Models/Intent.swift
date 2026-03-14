//
//  Intent.swift
//  Karaoke_support
//

import Foundation

/// 歌唱の意図（ドメインでは enum、永続化時は RawValue で扱う）
enum Intent: String, Codable {
	case shout
	case emo
	case practice
}
