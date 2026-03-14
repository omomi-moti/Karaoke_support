//
//  SingingSession.swift
//  Karaoke_support
//

import Foundation
import SwiftData

@Model
final class SingingSession {
	@Attribute(.unique) var id: UUID  // Idempotency Key
	var track: Track
	/// ドメインでは enum を使用し、永続化時は RawValue(String) で扱う。
	var intent: Intent
	var performedAt: Date
	var score: Int
	var memo: String?
}
