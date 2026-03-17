//
//  NetworkMonitorEnvironment.swift
//  Karaoke_support
//
//  I-006: NetworkMonitor の SwiftUI Environment 注入用。Data 層は SwiftUI に依存させず、
//  App 層で EnvironmentKey を定義する（レイヤーアーキテクチャ準拠）。
//

import SwiftUI

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
