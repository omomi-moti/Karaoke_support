//
//  InsightPeriod.swift
//  Karaoke_support
//

import Foundation

enum InsightPeriodError: Error {
	case failedToComputeCutoffDate
}

/// インサイト集計の対象期間。
enum InsightPeriod: String, Codable, CaseIterable {
	case oneMonth
	case threeMonths

	func cutoffDate(from now: Date = .now, calendar: Calendar = .current) throws -> Date {
		switch self {
		case .oneMonth:
			guard let date = calendar.date(byAdding: .month, value: -1, to: now) else {
				throw InsightPeriodError.failedToComputeCutoffDate
			}
			return date
		case .threeMonths:
			guard let date = calendar.date(byAdding: .month, value: -3, to: now) else {
				throw InsightPeriodError.failedToComputeCutoffDate
			}
			return date
		}
	}
}

