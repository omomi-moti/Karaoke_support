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
	/// 0〜100（小数第3位まで）。`nil` は点数を記録していない（点数の入力は任意）。
	var score: Double?
	var memo: String?

	init(
		id: UUID = UUID(),
		track: Track,
		intent: Intent,
		performedAt: Date = .now,
		score: Double?,
		memo: String? = nil
	) {
		precondition(score.map { (0...100).contains($0) } ?? true, "SingingSession score must be in 0...100.")
		self.id = id
		self.track = track
		self.intent = intent
		self.performedAt = performedAt
		self.score = score
		self.memo = memo
	}
}

