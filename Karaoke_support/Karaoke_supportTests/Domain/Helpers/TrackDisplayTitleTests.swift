//
//  TrackDisplayTitleTests.swift
//  Karaoke_supportTests
//
//  ``TrackDisplayTitle/shortenedSpotifyDisplayId`` の URI・生 ID・短縮ルールの検証。
//

import XCTest

@testable import Karaoke_support

final class TrackDisplayTitleTests: XCTestCase {
/// Spotify URIのトラックIDが上限を超える場合、最後のコロン以降が16文字に短縮され末尾に省略記号が付与されること
	func testShortenedSpotifyDisplayIdUsesCoreAfterLastColonForURI() {
		let longCore = String(repeating: "a", count: 20)
		let uri = "spotify:track:\(longCore)"
		let out = TrackDisplayTitle.shortenedSpotifyDisplayId(uri)
		XCTAssertEqual(out.count, 17)
		XCTAssertTrue(out.hasSuffix("…"))
		XCTAssertTrue(out.hasPrefix(String(repeating: "a", count: 16)))
	}
/// Spotify URIのトラックIDが上限以下の短い場合、短縮されずにコア部分がそのまま返されること
	func testShortenedSpotifyDisplayIdReturnsShortCoreUnchanged() {
		let uri = "spotify:track:shortid"
		XCTAssertEqual(TrackDisplayTitle.shortenedSpotifyDisplayId(uri), "shortid")
	}

/// コロンを含まない長い生IDの場合、文字列全体が16文字に短縮され末尾に省略記号が付与されること
	func testShortenedSpotifyDisplayIdRawIdWithoutColon() {
		let raw = String(repeating: "b", count: 20)
		let out = TrackDisplayTitle.shortenedSpotifyDisplayId(raw)
		XCTAssertEqual(out.count, 17)
		XCTAssertTrue(out.hasSuffix("…"))
	}
/// 末尾コロン直後のコア部分が空の場合、文字列全体を対象として短縮ルール（16文字以下ならそのまま、超えれば短縮）が適用されること
	func testShortenedSpotifyDisplayIdEmptyCoreFallsBackToWholeString() {
		// 末尾が `:` のみでコアが空 → 全体が 16 文字以下ならそのまま
		XCTAssertEqual(TrackDisplayTitle.shortenedSpotifyDisplayId("spotify:track:"), "spotify:track:")
		// コアは空だが全体が長い → 従来どおり全体を短縮
		let longNoCore = String(repeating: "x", count: 17) + ":"
		XCTAssertEqual(
			TrackDisplayTitle.shortenedSpotifyDisplayId(longNoCore),
			String(longNoCore.prefix(16)) + "…"
		)
	}
/// 手入力曲名とSpotify IDの両方が存在する場合、主タイトルとして手入力曲名が優先して返されること
	func testPrimaryPrefersUserEnteredName() {
		let track = Track(userEnteredName: "表示名", spotifyTrackId: "spotify:track:ignored")
		XCTAssertEqual(TrackDisplayTitle.primary(for: track), "表示名")
	}
}
