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
	/// 0〜100。小数第二位まで有効。桁数・丸めは ViewModel で制御する。
	var score: Double
	var memo: String?

	init(
		id: UUID = UUID(),
		track: Track,
		intent: Intent,
		performedAt: Date = .now,
		score: Double,
		memo: String? = nil
	) {
		assert(score >= 0 && score <= 100, "SingingSession score must be in 0...100.")
		self.id = id
		self.track = track
		self.intent = intent
		self.performedAt = performedAt
		self.score = score
		self.memo = memo
	}
}
