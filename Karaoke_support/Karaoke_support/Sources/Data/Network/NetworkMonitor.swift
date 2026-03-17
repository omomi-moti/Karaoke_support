//
//  NetworkMonitor.swift
//  Karaoke_support
//
//  I-006: ネットワーク監視ユーティリティ。NWPathMonitor で online/offline を検知し、
//  @Environment(\.networkMonitor) で参照できるよう App 起点で注入する（I-012 等でオフライン判定に使用）。
//

import Foundation
import Network
import SwiftUI

@Observable
public final class NetworkMonitor {
	private let monitor: NWPathMonitor
	private let queue: DispatchQueue
	/// 接続状態。true: online, false: offline。
	public private(set) var isOnline: Bool = false

	public init(queue: DispatchQueue = DispatchQueue(label: "com.karaokesupport.networkmonitor")) {
		self.monitor = NWPathMonitor()
		self.queue = queue
		self.isOnline = monitor.currentPath.status == .satisfied
		monitor.pathUpdateHandler = { [weak self] path in
			DispatchQueue.main.async {
				self?.isOnline = path.status == .satisfied
			}
		}
		monitor.start(queue: queue)
	}

	deinit {
		monitor.cancel()
	}
}

// MARK: - Environment

private struct NetworkMonitorEnvironmentKey: EnvironmentKey {
	static let defaultValue: NetworkMonitor = NetworkMonitor()
}

public extension EnvironmentValues {
	var networkMonitor: NetworkMonitor {
		get { self[NetworkMonitorEnvironmentKey.self] }
		set { self[NetworkMonitorEnvironmentKey.self] = newValue }
	}
}
