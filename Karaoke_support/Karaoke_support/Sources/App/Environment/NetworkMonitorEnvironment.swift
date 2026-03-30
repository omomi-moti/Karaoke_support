//
//  NetworkMonitorEnvironment.swift
//  Karaoke_support
//
//  I-006: NetworkMonitor の SwiftUI Environment 注入用。Data 層は SwiftUI に依存させず、
//  App 層で EnvironmentKey を定義する（レイヤーアーキテクチャ準拠）。
//

import SwiftUI

private struct NetworkMonitorEnvironmentKey: EnvironmentKey {
	/// App 起点で注入されるのが基本だが、未注入（プレビュー等）でも落ちないよう
	/// 監視しないインスタンスを MainActor 上で生成して返す。
	@MainActor private static let previewDefault = NetworkMonitor(startsMonitoring: false)
	@MainActor static var defaultValue: NetworkMonitor { previewDefault }
}

public extension EnvironmentValues {
	var networkMonitor: NetworkMonitor {
		get { self[NetworkMonitorEnvironmentKey.self] }
		set { self[NetworkMonitorEnvironmentKey.self] = newValue }
	}
}
