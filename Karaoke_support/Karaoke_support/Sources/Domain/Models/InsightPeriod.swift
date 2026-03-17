//
//  InsightPeriod.swift
//  Karaoke_support
//

import Foundation

/// インサイト集計の対象期間。
enum InsightPeriod: String, Codable, CaseIterable {
	case oneMonth
	case threeMonths

	func cutoffDate(from now: Date = .now, calendar: Calendar = .current) -> Date? {
		switch self {
		case .oneMonth:
			return calendar.date(byAdding: .month, value: -1, to: now)
		case .threeMonths:
			return calendar.date(byAdding: .month, value: -3, to: now)
		}
	}
}

