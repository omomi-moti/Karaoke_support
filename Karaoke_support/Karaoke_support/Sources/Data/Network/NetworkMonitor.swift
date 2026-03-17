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
	private let monitor: NWPathMonitor?
	private let queue: DispatchQueue
	/// 接続状態。true: online, false: offline。監視しないインスタンス（startsMonitoring: false）のときは常に false。
	public private(set) var isOnline: Bool = false

	/// - Parameter startsMonitoring: false のときは NWPathMonitor を起動しない（プレビュー・EnvironmentKey の default 用）。
	public init(
		queue: DispatchQueue = DispatchQueue(label: "com.karaokesupport.networkmonitor"),
		startsMonitoring: Bool = true
	) {
		self.queue = queue
		if startsMonitoring {
			let m = NWPathMonitor()
			self.monitor = m
			self.isOnline = m.currentPath.status == .satisfied
			m.pathUpdateHandler = { [weak self] path in
				DispatchQueue.main.async {
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
}

// MARK: - Environment

private struct NetworkMonitorEnvironmentKey: EnvironmentKey {
	/// 注入されていないコンテキスト（プレビュー等）用。監視は行わず、isOnline は常に false。
	static let defaultValue: NetworkMonitor = NetworkMonitor(startsMonitoring: false)
}

public extension EnvironmentValues {
	var networkMonitor: NetworkMonitor {
		get { self[NetworkMonitorEnvironmentKey.self] }
		set { self[NetworkMonitorEnvironmentKey.self] = newValue }
	}
}
