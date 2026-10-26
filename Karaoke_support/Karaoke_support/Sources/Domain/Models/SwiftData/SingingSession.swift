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
	/// 記録をどこから付けたか（保存する値）。`nil` は入口を記録し始める前（#120）に付けた記録。
	/// 項目を足したときの自動の移行では、前からある記録に初期値が入らず空のままになる。空を許さない型だと読んだときに落ちるので、空を許す（ADR 0034）。
	/// 新しい記録では `init` が必ず値を入れる。編集で更新しても変えない（``SessionRepositoryProtocol/updateRecordingSession(_:)``）。
	private(set) var recordedSource: RecordSource?

	/// 記録をどこから付けたか。入口を記録し始める前の記録は `.manual` として読む。
	var source: RecordSource { recordedSource ?? .manual }

	/// また歌いたいか（ハート。保存する値）。`nil` はハートを付けられるようになる前（#124）の記録で、OFF として読む（ADR 0034 と同じ形）。
	/// 新しい記録では `init` が必ず値を入れる。編集で更新すると書き換わる。
	var recordedWantAgain: Bool?

	/// また歌いたいか（ハート）。ハートを付けられるようになる前の記録は `false` として読む。
	var wantAgain: Bool { recordedWantAgain ?? false }

	init(
		id: UUID = UUID(),
		track: Track,
		intent: Intent,
		performedAt: Date = .now,
		score: Double?,
		memo: String? = nil,
		source: RecordSource = .manual,
		wantAgain: Bool = false
	) {
		precondition(score.map { (0...100).contains($0) } ?? true, "SingingSession score must be in 0...100.")
		self.id = id
		self.track = track
		self.intent = intent
		self.performedAt = performedAt
		self.score = score
		self.memo = memo
		self.recordedSource = source
		self.recordedWantAgain = wantAgain
	}
}

