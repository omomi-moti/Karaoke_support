//
//  SessionRepositoryError.swift
//  Karaoke_support
//
//  I-003: SessionRepository のエラー型。
//

import Foundation

/// SessionRepository のエラー。
enum SessionRepositoryError: Error {
	/// 無効な引数（limit / offset が負など）。
	case invalidParameter(String)
}
