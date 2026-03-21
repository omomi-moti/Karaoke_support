//
//  NetworkMonitor.swift
//  Karaoke_support
//
//  I-006: ネットワーク監視ユーティリティ。NWPathMonitor で online/offline を検知する。
//  Environment 注入は App 層の NetworkMonitorEnvironment.swift で行う（Data 層は SwiftUI 非依存）。
//

import Foundation
import Network
import Observation

@MainActor
@Observable
public final class NetworkMonitor {
	/// `deinit` は非隔離のため、`NWPathMonitor` の参照だけ `nonisolated(unsafe)` にして `cancel()` を許可する。
	/// 読み書きは `@MainActor` の `init` / `refreshStatus` に限定する。
	nonisolated(unsafe) private var monitor: NWPathMonitor?
	private let queue: DispatchQueue
	/// 接続状態。true: online, false: offline。監視しないインスタンス（startsMonitoring: false）のときは常に false。
	public private(set) var isOnline: Bool = false

	/// - Parameter queue: pathUpdateHandler が実行されるキュー。.main にすると isOnline の更新がメインスレッドで行われる（推奨）。
	/// - Parameter startsMonitoring: false のときは NWPathMonitor を起動しない（プレビュー・EnvironmentKey の default 用）。
	public init(
		queue: DispatchQueue = .main,
		startsMonitoring: Bool = true
	) {
		self.queue = queue
		if startsMonitoring {
			let m = NWPathMonitor()
			self.monitor = m
			self.isOnline = m.currentPath.status == .satisfied

			m.pathUpdateHandler = { [weak self] path in
				Task { @MainActor [weak self] in
					self?.isOnline = path.status == .satisfied
				}
			}
			m.start(queue: queue)
		} else {
			self.monitor = nil
		}
	}

	deinit {
		monitor?.cancel()
	}

	/// 「リトライ」等の明示操作時に、現在のネットワーク状態を再評価する。
	public func refreshStatus() {
		// エミュレータ等で経路切替後に currentPath が更新されないケースがあるため、
		// stuck した NWPathMonitor インスタンスを作り直して回復を狙う。
		monitor?.cancel()
		let newMonitor = NWPathMonitor()
		self.monitor = newMonitor
		newMonitor.pathUpdateHandler = { [weak self] path in
			Task { @MainActor [weak self] in
				guard let self else { return }
				self.isOnline = path.status == .satisfied
			}
		}

		newMonitor.start(queue: queue)
		isOnline = newMonitor.currentPath.status == .satisfied
	}
}
