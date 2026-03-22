//
//  SessionRepositoryError.swift
//  Karaoke_support
//
//  I-003: SessionRepository のエラー型。
//

import Foundation

/// SessionRepository のエラー。
enum SessionRepositoryError: Error, Equatable {
	/// 無効な引数（limit / offset が負など）。
	case invalidParameter(String)
	/// ``updateRecordingSession`` 対象の ``SingingSession.id`` が存在しない。
	case sessionNotFound(UUID)
	/// 編集時に別の ``Track`` へ差し替えることは未対応（曲替えは別仕様）。
	case sessionUpdateTrackChangeNotSupported
}
