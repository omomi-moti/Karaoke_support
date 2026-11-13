#if DEBUG || BETA
import Foundation
import SwiftData
import Testing

@testable import Karaoke_support

/// テストごとに別のホスト名を割り当て、そのホストへの通信だけを差し替える。テストを並べて流しても混ざらない。
private final class StubURLProtocol: URLProtocol {
	typealias Handler = @Sendable (URLRequest, Data?) throws -> (Int, Data)

	private static let lock = NSLock()
	nonisolated(unsafe) private static var handlers: [String: Handler] = [:]

	static func register(_ handler: @escaping Handler) -> URL {
		let host = "\(UUID().uuidString.lowercased()).test"
		lock.withLock { handlers[host] = handler }
		return URL(string: "https://\(host)")!
	}

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		let handler = Self.lock.withLock { request.url?.host.flatMap { Self.handlers[$0] } }
		guard let handler, let url = request.url else {
			client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
			return
		}
		do {
			let (status, data) = try handler(request, Self.readBody(request))
			let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
			client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
			client?.urlProtocol(self, didLoad: data)
			client?.urlProtocolDidFinishLoading(self)
		} catch {
			client?.urlProtocol(self, didFailWithError: error)
		}
	}

	override func stopLoading() {}

	/// URLSession は本文を stream にして渡すので、読み直す。
	private static func readBody(_ request: URLRequest) -> Data? {
		if let body = request.httpBody { return body }
		guard let stream = request.httpBodyStream else { return nil }
		stream.open()
		defer { stream.close() }
		var data = Data()
		var buffer = [UInt8](repeating: 0, count: 1024)
		while stream.hasBytesAvailable {
			let count = stream.read(&buffer, maxLength: buffer.count)
			guard count > 0 else { break }
			data.append(buffer, count: count)
		}
		return data
	}
}

/// 受けたリクエストを覚える。
private final class RequestLog: @unchecked Sendable {
	private let lock = NSLock()
	private var _requests: [(URLRequest, Data?)] = []

	func append(_ request: URLRequest, _ body: Data?) {
		lock.withLock { _requests.append((request, body)) }
	}

	var count: Int { lock.withLock { _requests.count } }
	var last: (URLRequest, Data?)? { lock.withLock { _requests.last } }
	var puts: [(URLRequest, Data?)] { lock.withLock { _requests.filter { $0.0.httpMethod == "PUT" } } }
	var methods: [String] { lock.withLock { _requests.compactMap { $0.0.httpMethod } } }
}

private final class InMemoryTokenStore: ServerTokenStoring, @unchecked Sendable {
	private let lock = NSLock()
	private var token: String?

	init(token: String? = "klog_saved") {
		self.token = token
	}

	func read() throws -> String? { lock.withLock { token } }
	func save(_ token: String) throws { lock.withLock { self.token = token } }
	func delete() throws { lock.withLock { token = nil } }
}

@MainActor
private final class InMemoryBackupState: BackupStateStoring {
	var isEnabled = false
	var consentVersion: Int?
	var lastRevision: Int?
	var lastSucceededAt: Date?
	var lastFailure: BackupFailure?
	private(set) var clearCount = 0

	/// オンで、今の版の同意がある状態。
	static func active(lastRevision: Int? = nil, lastFailure: BackupFailure? = nil) -> InMemoryBackupState {
		let state = InMemoryBackupState()
		state.isEnabled = true
		state.consentVersion = BackupStatus.currentConsentVersion
		state.lastRevision = lastRevision
		state.lastFailure = lastFailure
		return state
	}

	var isCleared: Bool {
		!isEnabled && consentVersion == nil && lastRevision == nil && lastSucceededAt == nil && lastFailure == nil
	}

	func clear() {
		isEnabled = false
		consentVersion = nil
		lastRevision = nil
		lastSucceededAt = nil
		lastFailure = nil
		clearCount += 1
	}
}

@MainActor
private final class FakeSnapshotReader: BackupSnapshotReading {
	var snapshot: BackupSnapshot

	init(sessionCount: Int = 2) {
		snapshot = Self.snapshot(sessionCount: sessionCount)
	}

	func readSnapshot() throws -> BackupSnapshot { snapshot }

	static func snapshot(sessionCount: Int, score: Double = 80) -> BackupSnapshot {
		let trackID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
		let date = Date(timeIntervalSince1970: 1_700_000_000.25)
		return BackupSnapshot(
			tracks: [BackupSnapshotTrack(id: trackID, userEnteredName: "曲", createdAt: date, updatedAt: date)],
			sessions: (0..<sessionCount).map { index in
				BackupSnapshotSession(
					id: UUID(uuidString: String(format: "00000000-0000-0000-0001-%012d", index))!,
					trackId: trackID, intent: .shout, performedAt: date, score: score,
					recordedSource: .manual, recordedWantAgain: false, recordedIsCompleted: true
				)
			}
		)
	}
}

private func putOK(revision: Int) -> (Int, String) {
	(200, #"{"revision":\#(revision),"updatedAt":"2026-11-13T01:02:03.123456Z"}"#)
}

private func summaryOK(revision: Int, sessionCount: Int) -> (Int, String) {
	(200, #"{"revision":\#(revision),"schemaVersion":1,"trackCount":1,"sessionCount":\#(sessionCount),"updatedAt":"2026-11-13T01:02:03Z"}"#)
}

/// テストが開けるまで、スタブの返事を止めておく。送っている途中に起きることを、待つ時間に頼らずに作るため。
private final class ResponseGate: @unchecked Sendable {
	private let condition = NSCondition()
	private var isOpen = false

	func wait() {
		condition.lock()
		defer { condition.unlock() }
		let deadline = Date().addingTimeInterval(5)
		while !isOpen, condition.wait(until: deadline) {}
	}

	func open() {
		condition.lock()
		isOpen = true
		condition.broadcast()
		condition.unlock()
	}
}

/// スタブが返すステータスを、テストの途中で切り替える。
private final class StatusSwitch: @unchecked Sendable {
	private let lock = NSLock()
	private var _status = 200

	var status: Int {
		get { lock.withLock { _status } }
		set { lock.withLock { _status = newValue } }
	}
}

@MainActor
private final class StartFlag {
	var isStarted = false
}

/// `condition` が満たされるまで待つ。5 秒で満たされなければ失敗にする。
@MainActor
private func waitUntil(_ condition: () -> Bool) async throws {
	let deadline = ContinuousClock.now + .seconds(5)
	while !condition() {
		try #require(ContinuousClock.now < deadline, "5 秒待っても満たされなかった")
		try await Task.sleep(for: .milliseconds(5))
	}
}

/// `operation` を別のタスクで始め、最初に待つところまで進んでから返す。
/// 呼び出しを受け付けた（予約した・オフにした）後で、次の操作をするため。
@MainActor
private func start<T: Sendable>(_ operation: @escaping @MainActor @Sendable () async throws -> T) async throws -> Task<T, any Error> {
	let flag = StartFlag()
	let task = Task { @MainActor in
		flag.isStarted = true
		return try await operation()
	}
	try await waitUntil { flag.isStarted }
	return task
}

@Suite("RemoteBackupRepository")
@MainActor
struct RemoteBackupRepositoryTests {
	private func makeRepository(
		tokenStore: InMemoryTokenStore = InMemoryTokenStore(),
		state: InMemoryBackupState? = nil,
		reader: (any BackupSnapshotReading)? = nil,
		log: RequestLog = RequestLog(),
		respond: @escaping @Sendable (URLRequest) throws -> (Int, String)
	) -> RemoteBackupRepository {
		let baseURL = StubURLProtocol.register { request, body in
			log.append(request, body)
			let (status, text) = try respond(request)
			return (status, Data(text.utf8))
		}
		let session = APIClient.makeSession(protocolClasses: [StubURLProtocol.self])
		return RemoteBackupRepository(client: APIClient(baseURL: baseURL, session: session), tokenStore: tokenStore, state: state ?? .active(), reader: reader ?? FakeSnapshotReader())
	}

	// MARK: 送らないとき

	@Test("オフなら、どのきっかけでも送らない", arguments: [BackupTrigger.background, .foreground, .manual])
	func notActiveWhenOff(trigger: BackupTrigger) async throws {
		let log = RequestLog()
		let repository = makeRepository(state: InMemoryBackupState(), log: log) { _ in putOK(revision: 1) }

		#expect(try await repository.backUp(trigger: trigger) == .notActive)
		#expect(log.count == 0)
	}

	@Test("同意の版が今のものでなければ、オンでも送らない")
	func notActiveWithOldConsent() async throws {
		let state = InMemoryBackupState.active()
		state.consentVersion = BackupStatus.currentConsentVersion - 1
		let log = RequestLog()
		let repository = makeRepository(state: state, log: log) { _ in putOK(revision: 1) }

		#expect(try await repository.backUp(trigger: .background) == .notActive)
		#expect(log.count == 0)
	}

	@Test("記録が 1 件もなければ送らない")
	func noRecords() async throws {
		let log = RequestLog()
		let repository = makeRepository(reader: FakeSnapshotReader(sessionCount: 0), log: log) { _ in putOK(revision: 1) }

		#expect(try await repository.backUp(trigger: .manual) == .noRecords)
		#expect(log.count == 0)
	}

	@Test("前回送った中身と同じなら、2 回目は送らない。変わったら送る")
	func unchanged() async throws {
		let reader = FakeSnapshotReader()
		let log = RequestLog()
		let repository = makeRepository(reader: reader, log: log) { _ in putOK(revision: log.count) }

		#expect(try await repository.backUp(trigger: .background) == .uploaded)
		#expect(try await repository.backUp(trigger: .background) == .unchanged)
		#expect(try await repository.backUp(trigger: .manual) == .unchanged)
		#expect(log.count == 1)

		reader.snapshot = FakeSnapshotReader.snapshot(sessionCount: 2, score: 99)
		#expect(try await repository.backUp(trigger: .background) == .uploaded)
		#expect(log.count == 2)
	}

	@Test("前に戻ったときは、前回やり直す失敗でなければ送らない", arguments: [nil, BackupFailure.tooLarge, .remoteDeletionFailed])
	func foregroundWithoutRetryableFailure(lastFailure: BackupFailure?) async throws {
		let log = RequestLog()
		let repository = makeRepository(state: .active(lastFailure: lastFailure), log: log) { _ in putOK(revision: 1) }

		#expect(try await repository.backUp(trigger: .foreground) == .nothingToRetry)
		#expect(log.count == 0)
	}

	// MARK: 送るとき

	@Test("初めて送るときは If-None-Match: * を付け、返った版と日時を置く")
	func firstUploadUsesIfNoneMatch() async throws {
		let state = InMemoryBackupState.active()
		let log = RequestLog()
		let repository = makeRepository(state: state, log: log) { _ in putOK(revision: 1) }

		#expect(try await repository.backUp(trigger: .manual) == .uploaded)

		let (request, body) = try #require(log.last)
		#expect(request.httpMethod == "PUT")
		#expect(request.url?.path == "/v1/backup")
		#expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer klog_saved")
		#expect(request.value(forHTTPHeaderField: "If-None-Match") == "*")
		#expect(request.value(forHTTPHeaderField: "If-Match") == nil)
		let json = try JSONSerialization.jsonObject(with: try #require(body))
		let sent = try #require(json as? [String: Any])
		#expect(sent["schemaVersion"] as? Int == 1)
		#expect(sent["trackCount"] as? Int == 1)
		#expect(sent["sessionCount"] as? Int == 2)
		#expect(sent["payload"] is [String: Any])

		#expect(state.lastRevision == 1)
		let succeededAt = try #require(state.lastSucceededAt)
		#expect(abs(succeededAt.timeIntervalSince1970 - 1_794_531_723.123) < 0.001)
		#expect(state.lastFailure == nil)
	}

	@Test("2 回目からは、最後に送った版を If-Match に付ける")
	func laterUploadUsesIfMatch() async throws {
		let state = InMemoryBackupState.active(lastRevision: 7)
		let log = RequestLog()
		let repository = makeRepository(state: state, log: log) { _ in putOK(revision: 8) }

		#expect(try await repository.backUp(trigger: .background) == .uploaded)

		let (request, _) = try #require(log.last)
		#expect(request.value(forHTTPHeaderField: "If-Match") == "\"7\"")
		#expect(request.value(forHTTPHeaderField: "If-None-Match") == nil)
		#expect(state.lastRevision == 8)
	}

	@Test("日時は秒より下も送る")
	func sendsFractionalSeconds() async throws {
		let log = RequestLog()
		let repository = makeRepository(log: log) { _ in putOK(revision: 1) }

		_ = try await repository.backUp(trigger: .manual)

		let body = String(decoding: try #require(log.last?.1), as: UTF8.self)
		#expect(body.contains("2023-11-14T22:13:20.250Z"))
	}

	@Test("送っている間に呼ばれても、同時には送らない")
	func doesNotUploadTwiceAtOnce() async throws {
		let log = RequestLog()
		let repository = makeRepository(log: log) { _ in
			Thread.sleep(forTimeInterval: 0.2)
			return putOK(revision: 1)
		}

		async let first = repository.backUp(trigger: .background)
		async let second = repository.backUp(trigger: .manual)
		_ = try await (first, second)

		#expect(log.puts.count == 1)
	}

	@Test("送っている途中で記録が増えたら、終わった後に読み直して送る")
	func uploadsChangesMadeWhileUploading() async throws {
		let reader = FakeSnapshotReader()
		let log = RequestLog()
		let gate = ResponseGate()
		let repository = makeRepository(reader: reader, log: log) { _ in
			gate.wait()
			return putOK(revision: log.count)
		}

		let first = try await start { try await repository.backUp(trigger: .background) }
		try await waitUntil { log.puts.count == 1 }
		reader.snapshot = FakeSnapshotReader.snapshot(sessionCount: 3)
		let second = try await start { try await repository.backUp(trigger: .background) }
		gate.open()
		_ = try await first.value

		#expect(try await second.value == .uploaded)
		#expect(log.puts.count == 2)
		let body = try #require(log.puts.last?.1)
		let sent = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
		#expect(sent["sessionCount"] as? Int == 3)
	}

	@Test("送っている途中に何回呼ばれても、予約は 1 つにまとめる")
	func coalescesQueuedBackUps() async throws {
		let log = RequestLog()
		let gate = ResponseGate()
		let repository = makeRepository(log: log) { _ in
			gate.wait()
			throw URLError(.notConnectedToInternet)
		}

		let first = try await start { try? await repository.backUp(trigger: .background) }
		try await waitUntil { log.puts.count == 1 }
		let queued = [
			try await start { try? await repository.backUp(trigger: .background) },
			try await start { try? await repository.backUp(trigger: .foreground) },
			try await start { try? await repository.backUp(trigger: .background) },
		]
		gate.open()
		_ = try await first.value
		for task in queued {
			_ = try await task.value
		}

		#expect(log.puts.count == 2)
	}

	@Test("まとめた予約は、強いほうのきっかけ（ボタン）で動く")
	func queuedBackUpUsesStrongestTrigger() async throws {
		let state = InMemoryBackupState.active(lastRevision: 3)
		let log = RequestLog()
		let gate = ResponseGate()
		let repository = makeRepository(state: state, log: log) { _ in
			gate.wait()
			return (412, #"{"error":"precondition_failed"}"#)
		}

		let first = try await start { try? await repository.backUp(trigger: .manual) }
		try await waitUntil { log.puts.count == 1 }
		let automatic = try await start { try? await repository.backUp(trigger: .background) }
		let manual = try await start { try? await repository.backUp(trigger: .manual) }
		gate.open()
		_ = try await (first.value, automatic.value, manual.value)

		#expect(log.puts.count == 2)
		#expect(state.lastFailure == .needsConfirmation)
	}

	// MARK: 失敗したとき

	@Test("412 なら「確認が要る」を置き、その後は自動では送らない")
	func conflictStopsAutomaticUploads() async throws {
		let state = InMemoryBackupState.active(lastRevision: 3)
		let log = RequestLog()
		let repository = makeRepository(state: state, log: log) { _ in (412, #"{"error":"precondition_failed"}"#) }

		await #expect(throws: BackupFailure.needsConfirmation) {
			_ = try await repository.backUp(trigger: .background)
		}
		#expect(state.lastFailure == .needsConfirmation)
		#expect(state.lastRevision == 3)

		#expect(try await repository.backUp(trigger: .background) == .waitingForConfirmation)
		#expect(try await repository.backUp(trigger: .foreground) == .waitingForConfirmation)
		#expect(log.count == 1)
	}

	@Test("401 なら、端末のトークンとバックアップの状態を消す")
	func unauthorizedSignsOutLocally() async throws {
		let tokenStore = InMemoryTokenStore()
		let state = InMemoryBackupState.active(lastRevision: 3)
		let repository = makeRepository(tokenStore: tokenStore, state: state) { _ in (401, #"{"error":"unauthorized"}"#) }

		await #expect(throws: BackupFailure.signInRequired) {
			_ = try await repository.backUp(trigger: .background)
		}
		#expect(try tokenStore.read() == nil)
		#expect(state.isCleared)
	}

	@Test("送っている途中に状態が消されたら（サインアウト）、返事の版と日時を書かない")
	func clearedWhileUploadingKeepsStateCleared() async throws {
		let state = InMemoryBackupState.active(lastRevision: 3)
		let log = RequestLog()
		let gate = ResponseGate()
		let repository = makeRepository(state: state, log: log) { _ in
			gate.wait()
			return putOK(revision: 4)
		}

		let upload = try await start { try await repository.backUp(trigger: .manual) }
		try await waitUntil { log.puts.count == 1 }
		state.clear()
		gate.open()
		_ = try await upload.value

		#expect(state.isCleared)
	}

	@Test("送っている途中に状態が消され、別のアカウントでオンにしたら、前の版を使わずに作り直す")
	func clearedAndEnabledWhileUploadingStartsFresh() async throws {
		let state = InMemoryBackupState.active(lastRevision: 3)
		let log = RequestLog()
		let gate = ResponseGate()
		let repository = makeRepository(state: state, log: log) { request in
			if request.value(forHTTPHeaderField: "If-None-Match") == "*" {
				return putOK(revision: 1)
			}
			gate.wait()
			return putOK(revision: 4)
		}

		let upload = try await start { try await repository.backUp(trigger: .manual) }
		try await waitUntil { log.puts.count == 1 }
		state.clear()
		let enabled = try await start { try await repository.enable() }
		gate.open()
		#expect(try await enabled.value == .uploaded)
		_ = try await upload.value

		#expect(log.puts.count == 2)
		#expect(log.last?.0.value(forHTTPHeaderField: "If-None-Match") == "*")
		#expect(state.lastRevision == 1)
	}

	@Test("状態が消された後に、前の送信が 401 で返っても、新しいトークンと状態を消さない")
	func unauthorizedAfterClearKeepsNewSignIn() async throws {
		let tokenStore = InMemoryTokenStore()
		let state = InMemoryBackupState.active(lastRevision: 3)
		let log = RequestLog()
		let gate = ResponseGate()
		let repository = makeRepository(tokenStore: tokenStore, state: state, log: log) { _ in
			gate.wait()
			return (401, #"{"error":"unauthorized"}"#)
		}

		let upload = try await start { try await repository.backUp(trigger: .manual) }
		try await waitUntil { log.puts.count == 1 }
		state.clear()
		try tokenStore.save("klog_new")
		state.isEnabled = true
		state.consentVersion = BackupStatus.currentConsentVersion
		gate.open()

		await #expect(throws: BackupFailure.signInRequired) {
			_ = try await upload.value
		}
		#expect(try tokenStore.read() == "klog_new")
		#expect(state.isEnabled)
	}

	@Test("前回届いた中身と同じに戻ったら、送らずに最後の失敗を消す。確認が要るときは残す", arguments: [
		(500, BackupFailure.server, BackupFailure?.none),
		(412, BackupFailure.needsConfirmation, BackupFailure?.some(.needsConfirmation)),
	])
	func unchangedClearsStaleFailure(status: Int, failure: BackupFailure, expected: BackupFailure?) async throws {
		let state = InMemoryBackupState.active()
		let reader = FakeSnapshotReader(sessionCount: 2)
		let statusSwitch = StatusSwitch()
		let repository = makeRepository(state: state, reader: reader) { _ in
			statusSwitch.status == 200 ? putOK(revision: 1) : (statusSwitch.status, #"{"error":"x"}"#)
		}
		#expect(try await repository.backUp(trigger: .manual) == .uploaded)

		reader.snapshot = FakeSnapshotReader.snapshot(sessionCount: 3)
		statusSwitch.status = status
		_ = try? await repository.backUp(trigger: .manual)
		#expect(state.lastFailure == failure)

		reader.snapshot = FakeSnapshotReader.snapshot(sessionCount: 2)
		#expect(try await repository.backUp(trigger: .manual) == .unchanged)
		#expect(state.lastFailure == expected)
	}

	@Test("トークンがなければ、通信せずに signInRequired")
	func noToken() async throws {
		let log = RequestLog()
		let repository = makeRepository(tokenStore: InMemoryTokenStore(token: nil), log: log) { _ in putOK(revision: 1) }

		await #expect(throws: BackupFailure.signInRequired) {
			_ = try await repository.backUp(trigger: .manual)
		}
		#expect(log.count == 0)
	}

	@Test("失敗したら種類ごとの理由を置き、版は変えない", arguments: [
		(0, BackupFailure.unreachable),
		(500, BackupFailure.server),
		(413, BackupFailure.tooLarge),
		(200, BackupFailure.server),
	])
	func failures(status: Int, expected: BackupFailure) async throws {
		let state = InMemoryBackupState.active(lastRevision: 3)
		let repository = makeRepository(state: state) { _ in
			if status == 0 { throw URLError(.notConnectedToInternet) }
			return (status, status == 200 ? "not json" : #"{"error":"x"}"#)
		}

		await #expect(throws: expected) {
			_ = try await repository.backUp(trigger: .background)
		}
		#expect(state.lastFailure == expected)
		#expect(state.lastRevision == 3)
		#expect(state.isEnabled)
	}

	@Test("届かなかったら、次に前に戻ったときに送り直す")
	func foregroundRetriesAfterUnreachable() async throws {
		let state = InMemoryBackupState.active()
		let log = RequestLog()
		let repository = makeRepository(state: state, log: log) { _ in
			if log.count == 1 { throw URLError(.notConnectedToInternet) }
			return putOK(revision: 1)
		}

		await #expect(throws: BackupFailure.unreachable) {
			_ = try await repository.backUp(trigger: .background)
		}
		#expect(try await repository.backUp(trigger: .foreground) == .uploaded)
		#expect(state.lastFailure == nil)
		#expect(log.count == 2)
	}

	// MARK: 確かめてから置き換える

	@Test("412 の後、確かめた版を If-Match に付けて置き換える")
	func replaceAfterConfirmation() async throws {
		let state = InMemoryBackupState.active(lastRevision: 3, lastFailure: .needsConfirmation)
		let log = RequestLog()
		let repository = makeRepository(state: state, log: log) { request in
			request.httpMethod == "GET" ? summaryOK(revision: 5, sessionCount: 9) : putOK(revision: 6)
		}

		let conflict = try await repository.fetchConflict()
		#expect(conflict == BackupConflict(serverRevision: 5, serverSessionCount: 9, localSessionCount: 2))
		#expect(log.last?.0.url?.path == "/v1/backup/summary")

		#expect(try await repository.replaceRemote(confirmed: conflict) == .uploaded)
		#expect(log.last?.0.value(forHTTPHeaderField: "If-Match") == "\"5\"")
		#expect(state.lastRevision == 6)
		#expect(state.lastFailure == nil)
	}

	@Test("サーバーの控えがなくなっていたら、If-None-Match: * で置き換える")
	func replaceWhenServerBackupIsGone() async throws {
		let state = InMemoryBackupState.active(lastRevision: 3, lastFailure: .needsConfirmation)
		let log = RequestLog()
		let repository = makeRepository(state: state, log: log) { request in
			request.httpMethod == "GET" ? (404, #"{"error":"not_found"}"#) : putOK(revision: 1)
		}

		let conflict = try await repository.fetchConflict()
		#expect(conflict == BackupConflict(serverRevision: nil, serverSessionCount: 0, localSessionCount: 2))

		#expect(try await repository.replaceRemote(confirmed: conflict) == .uploaded)
		#expect(log.last?.0.value(forHTTPHeaderField: "If-None-Match") == "*")
		#expect(state.lastRevision == 1)
	}

	@Test("確かめている間にまた変わっていたら、もう一度確認が要る")
	func replaceConflictsAgain() async throws {
		let state = InMemoryBackupState.active(lastRevision: 3, lastFailure: .needsConfirmation)
		let repository = makeRepository(state: state) { _ in (412, #"{"error":"precondition_failed"}"#) }

		await #expect(throws: BackupFailure.needsConfirmation) {
			_ = try await repository.replaceRemote(confirmed: BackupConflict(serverRevision: 5, serverSessionCount: 9, localSessionCount: 2))
		}
		#expect(state.lastFailure == .needsConfirmation)
		#expect(state.lastRevision == 3)
	}

	// MARK: オフにする

	@Test("サーバーの控えの件数を読む。なければ nil")
	func remoteSessionCount() async throws {
		let found = makeRepository { _ in summaryOK(revision: 2, sessionCount: 4) }
		#expect(try await found.fetchRemoteSessionCount() == 4)

		let missing = makeRepository { _ in (404, #"{"error":"not_found"}"#) }
		#expect(try await missing.fetchRemoteSessionCount() == nil)
	}

	@Test("オフにすると DELETE /v1/backup を送り、消せたら状態を全部消す")
	func disableDeletesRemote() async throws {
		let state = InMemoryBackupState.active(lastRevision: 3)
		let log = RequestLog()
		let repository = makeRepository(state: state, log: log) { _ in (204, "") }

		try await repository.disable()

		let (request, _) = try #require(log.last)
		#expect(request.httpMethod == "DELETE")
		#expect(request.url?.path == "/v1/backup")
		#expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer klog_saved")
		#expect(state.isCleared)
	}

	@Test("オフにして消せなかったら、オフのまま「消せなかった」を置き、もう一度消せる")
	func disableFailureCanBeRetried() async throws {
		let state = InMemoryBackupState.active(lastRevision: 3)
		let log = RequestLog()
		let repository = makeRepository(state: state, log: log) { _ in
			if log.count == 1 { throw URLError(.notConnectedToInternet) }
			return (204, "")
		}

		await #expect(throws: BackupFailure.remoteDeletionFailed) {
			try await repository.disable()
		}
		#expect(!state.isEnabled)
		#expect(state.lastFailure == .remoteDeletionFailed)
		#expect(try await repository.backUp(trigger: .background) == .notActive)

		try await repository.retryRemoteDeletion()
		#expect(state.isCleared)
		#expect(log.count == 2)
	}

	@Test("オンに戻した後は、もう一度消すを押してもサーバーの控えを消さない")
	func retryDeletionDoesNothingWhenEnabled() async throws {
		let log = RequestLog()
		let repository = makeRepository(state: .active(), log: log) { _ in (204, "") }

		try await repository.retryRemoteDeletion()

		#expect(log.count == 0)
	}

	@Test("送っている途中でオフにし、すぐオンに戻したら、控えは消さずにオンのまま")
	func enableBeforeQueuedDeletion() async throws {
		let state = InMemoryBackupState.active(lastRevision: 3)
		let log = RequestLog()
		let gate = ResponseGate()
		let repository = makeRepository(state: state, log: log) { request in
			if request.httpMethod == "PUT" {
				gate.wait()
				return putOK(revision: 4)
			}
			return (204, "")
		}

		let upload = try await start { try await repository.backUp(trigger: .manual) }
		try await waitUntil { log.puts.count == 1 }
		let off = try await start { try await repository.disable() }
		let on = try await start { try await repository.enable() }
		gate.open()
		_ = try await upload.value
		try await off.value
		_ = try await on.value

		#expect(state.isEnabled)
		#expect(state.consentVersion == BackupStatus.currentConsentVersion)
		#expect(state.lastRevision == 4)
		#expect(!log.methods.contains("DELETE"))
	}

	@Test("消している途中でオンに戻したら、オンのまま、控えがない前提で送り直す")
	func enableWhileDeleting() async throws {
		let state = InMemoryBackupState.active(lastRevision: 3)
		let log = RequestLog()
		let gate = ResponseGate()
		let repository = makeRepository(state: state, log: log) { request in
			if request.httpMethod == "DELETE" {
				gate.wait()
				return (204, "")
			}
			return putOK(revision: 1)
		}

		let off = try await start { try await repository.disable() }
		try await waitUntil { log.count == 1 }
		let on = try await start { try await repository.enable() }
		gate.open()
		#expect(try await on.value == .uploaded)
		try await off.value

		#expect(log.methods == ["DELETE", "PUT"])
		#expect(log.last?.0.value(forHTTPHeaderField: "If-None-Match") == "*")
		#expect(state.isEnabled)
		#expect(state.lastRevision == 1)
		#expect(state.lastFailure == nil)
	}

	@Test("オンにすると、同意の版を置いてすぐ送る")
	func enableUploadsImmediately() async throws {
		let state = InMemoryBackupState()
		let log = RequestLog()
		let repository = makeRepository(state: state, log: log) { _ in putOK(revision: 1) }

		#expect(try await repository.enable() == .uploaded)
		#expect(state.isEnabled)
		#expect(state.consentVersion == BackupStatus.currentConsentVersion)
		#expect(log.last?.0.value(forHTTPHeaderField: "If-None-Match") == "*")
	}

	// MARK: メモ

	@Test("送る JSON に、メモの項目もメモの中身も入らない")
	func memoIsNeverSent() async throws {
		let container = try ModelContainer(for: Track.self, SingingSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
		let context = container.mainContext
		let track = Track(userEnteredName: "送ってよい曲名")
		context.insert(track)
		context.insert(SingingSession(track: track, intent: .emo, score: 88, memo: "送ってはいけないメモ"))
		try context.save()
		let log = RequestLog()
		let repository = makeRepository(reader: SwiftDataBackupSnapshotReader(modelContext: context), log: log) { _ in putOK(revision: 1) }

		#expect(try await repository.backUp(trigger: .manual) == .uploaded)

		let body = try #require(log.last?.1)
		let text = String(decoding: body, as: UTF8.self)
		#expect(text.contains("送ってよい曲名"))
		#expect(!text.contains("送ってはいけないメモ"))
		#expect(!Self.keys(in: try JSONSerialization.jsonObject(with: body)).contains("memo"))
	}

	/// JSON の中の、全部の深さの鍵を集める。
	private static func keys(in json: Any) -> Set<String> {
		switch json {
		case let object as [String: Any]:
			object.reduce(into: Set(object.keys)) { $0.formUnion(keys(in: $1.value)) }
		case let array as [Any]:
			array.reduce(into: Set<String>()) { $0.formUnion(keys(in: $1)) }
		default:
			[]
		}
	}
}
#endif
