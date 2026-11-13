#if DEBUG || BETA
import CryptoKit
import Foundation

/// 自前のサーバーに記録をバックアップする（ADR 0058）。
/// 中身を作る・前回と比べる・版の番号を条件に送る、をここで行う。送る・消す処理は 1 つずつ順に動かす。
@MainActor
final class RemoteBackupRepository: BackupRepositoryProtocol {
	private let client: APIClient
	private let tokenStore: any ServerTokenStoring
	private let state: any BackupStateStoring
	private let reader: any BackupSnapshotReading

	/// 最後に送れた中身のハッシュ。メモリにだけ持ち、同じなら送らない。
	private var lastUploadedHash: SHA256.Digest?
	/// 最後に始めた送信か削除。次の処理は、これが終わってから始める。
	private var latestOperation: Task<Void, Never>?
	/// まだ始まっていない `backUp` の予約。送っている途中に何回呼ばれても、この 1 つにまとめる。
	private var queuedBackUp: Task<BackupOutcome, any Error>?
	/// 予約が始まるときに使うきっかけ。まとめた中で、いちばん強いもの。
	private var queuedTrigger: BackupTrigger = .foreground

	init(client: APIClient, tokenStore: any ServerTokenStoring, state: any BackupStateStoring, reader: any BackupSnapshotReading) {
		self.client = client
		self.tokenStore = tokenStore
		self.state = state
		self.reader = reader
	}

	var status: BackupStatus {
		BackupStatus(
			isEnabled: state.isEnabled,
			consentVersion: state.consentVersion,
			lastSucceededAt: state.lastSucceededAt,
			lastFailure: state.lastFailure
		)
	}

	func enable() async throws -> BackupOutcome {
		state.isEnabled = true
		state.consentVersion = BackupStatus.currentConsentVersion
		state.lastFailure = nil
		lastUploadedHash = nil
		return try await runAfterLatest { try await self.performBackUp(trigger: .manual) }.value
	}

	func backUp(trigger: BackupTrigger) async throws -> BackupOutcome {
		if let queuedBackUp {
			queuedTrigger = Self.stronger(queuedTrigger, trigger)
			return try await queuedBackUp.value
		}
		queuedTrigger = trigger
		let task = runAfterLatest {
			let trigger = self.queuedTrigger
			self.queuedBackUp = nil
			return try await self.performBackUp(trigger: trigger)
		}
		queuedBackUp = task
		return try await task.value
	}

	/// 予約をまとめるときは、送る条件のゆるいほうにそろえる。ボタンは失敗をその場に出すので、いちばん強い。
	private static func stronger(_ lhs: BackupTrigger, _ rhs: BackupTrigger) -> BackupTrigger {
		func rank(_ trigger: BackupTrigger) -> Int {
			switch trigger {
			case .foreground: 0
			case .background: 1
			case .manual: 2
			}
		}
		return rank(lhs) >= rank(rhs) ? lhs : rhs
	}

	func fetchConflict() async throws -> BackupConflict {
		let localSessionCount = try readSnapshot().sessions.count
		let summary = try await fetchSummary()
		return BackupConflict(
			serverRevision: summary?.revision,
			serverSessionCount: summary?.sessionCount ?? 0,
			localSessionCount: localSessionCount
		)
	}

	func replaceRemote(confirmed conflict: BackupConflict) async throws -> BackupOutcome {
		try await runAfterLatest {
			guard self.status.isActive else { return .notActive }
			let snapshot = try self.readSnapshot()
			guard !snapshot.sessions.isEmpty else { return .noRecords }
			return try await self.upload(snapshot, ifMatch: conflict.serverRevision)
		}.value
	}

	func fetchRemoteSessionCount() async throws -> Int? {
		try await fetchSummary()?.sessionCount
	}

	func disable() async throws {
		state.isEnabled = false
		lastUploadedHash = nil
		try await runAfterLatest {
			guard !self.state.isEnabled else { return }
			try await self.deleteRemote()
		}.value
	}

	func retryRemoteDeletion() async throws {
		try await runAfterLatest {
			guard !self.state.isEnabled else { return }
			try await self.deleteRemote()
		}.value
	}

	/// 前に始めた送信か削除が終わってから `operation` を動かす。オフにした直後の削除が、送っている途中の送信より先に届かないようにするため。
	private func runAfterLatest<T: Sendable>(_ operation: @escaping @MainActor @Sendable () async throws -> T) -> Task<T, any Error> {
		let previous = latestOperation
		let task = Task { @MainActor in
			await previous?.value
			return try await operation()
		}
		latestOperation = Task { _ = try? await task.value }
		return task
	}

	private func performBackUp(trigger: BackupTrigger) async throws -> BackupOutcome {
		guard status.isActive else { return .notActive }
		switch trigger {
		case .background:
			if state.lastFailure == .needsConfirmation { return .waitingForConfirmation }
		case .foreground:
			if state.lastFailure == .needsConfirmation { return .waitingForConfirmation }
			guard state.lastFailure?.isRetriedAutomatically == true else { return .nothingToRetry }
		case .manual:
			break
		}

		let snapshot = try readSnapshot()
		guard !snapshot.sessions.isEmpty else { return .noRecords }
		return try await upload(snapshot, ifMatch: state.lastRevision, skipsUnchanged: true)
	}

	/// `ifMatch` の版を条件に送る。版がなければ、控えがないときだけ作る（`If-None-Match: *`）。
	/// 送っている途中に状態が消されたら（サインアウトなど）、返事を状態に書かない。前のアカウントの版や失敗を残さないため。
	private func upload(_ snapshot: BackupSnapshot, ifMatch revision: Int?, skipsUnchanged: Bool = false) async throws -> BackupOutcome {
		let clearCount = state.clearCount
		let body: Data
		do {
			body = try Self.encoder.encode(PutBackupRequest(snapshot: snapshot))
		} catch {
			throw record(.localReadFailed)
		}
		let hash = SHA256.hash(data: body)
		if skipsUnchanged, hash == lastUploadedHash {
			return .unchanged
		}

		let condition = revision.map { ["If-Match": "\"\($0)\""] } ?? ["If-None-Match": "*"]
		let token = try currentToken()
		let response: PutBackupResponse
		do {
			response = try await client.send("PUT", "v1/backup", jsonBody: body, headers: condition, bearer: token)
		} catch {
			let failure = failure(for: error)
			guard state.clearCount == clearCount else { throw failure }
			throw record(failure)
		}

		if state.clearCount == clearCount {
			state.lastRevision = response.revision
			state.lastSucceededAt = response.updatedAt
			state.lastFailure = nil
			lastUploadedHash = hash
		}
		return .uploaded
	}

	/// サーバーの控えを消す。消している間にオンに戻されたときは、オンの状態を消さない。
	/// 消している間に状態が消されたら、返事を状態に書かない。
	private func deleteRemote() async throws {
		let clearCount = state.clearCount
		let token = try currentToken()
		do {
			try await client.sendExpectingNoContent("DELETE", "v1/backup", bearer: token)
		} catch {
			let failure = failure(for: error)
			guard state.clearCount == clearCount else {
				throw failure == .signInRequired ? failure : .remoteDeletionFailed
			}
			if failure == .signInRequired {
				throw record(failure)
			}
			if !state.isEnabled {
				state.lastFailure = .remoteDeletionFailed
			}
			throw BackupFailure.remoteDeletionFailed
		}
		guard state.clearCount == clearCount else { return }
		if state.isEnabled {
			state.lastRevision = nil
		} else {
			state.clear()
		}
	}

	private func fetchSummary() async throws -> BackupSummaryResponse? {
		let clearCount = state.clearCount
		let token = try currentToken()
		do {
			return try await client.send("GET", "v1/backup/summary", bearer: token)
		} catch APIError.status(404) {
			return nil
		} catch {
			let failure = failure(for: error)
			if failure == .signInRequired, state.clearCount == clearCount {
				signOutLocally()
			}
			throw failure
		}
	}

	private func readSnapshot() throws -> BackupSnapshot {
		do {
			return try reader.readSnapshot()
		} catch {
			throw record(.localReadFailed)
		}
	}

	private func currentToken() throws -> String {
		guard let token = try? tokenStore.read() else {
			throw record(.signInRequired)
		}
		return token
	}

	private func failure(for error: any Error) -> BackupFailure {
		switch error as? APIError {
		case .unauthorized:
			.signInRequired
		case .unreachable:
			.unreachable
		case .status(412):
			.needsConfirmation
		case .status(413):
			.tooLarge
		case .status, .invalidResponse, nil:
			.server
		}
	}

	/// 失敗を最後の失敗として置く。401 のときは置かずに、サインアウトと同じく端末のトークンとバックアップの状態を消す。
	private func record(_ failure: BackupFailure) -> BackupFailure {
		if failure == .signInRequired {
			signOutLocally()
		} else {
			state.lastFailure = failure
		}
		return failure
	}

	private func signOutLocally() {
		try? tokenStore.delete()
		state.clear()
		lastUploadedHash = nil
	}

	/// 同じ記録なら同じバイト列になるように、鍵の順をそろえる。日時は秒より下も残す（取り込んだときに並びが変わらないように）。
	private static let encoder: JSONEncoder = {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]
		encoder.dateEncodingStrategy = .custom { date, encoder in
			var container = encoder.singleValueContainer()
			try container.encode(date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
		}
		return encoder
	}()
}
#endif
