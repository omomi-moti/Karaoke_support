//
//  TrackDisplayTitleTests.swift
//  Karaoke_supportTests
//
//  ``TrackDisplayTitle/shortenedSpotifyDisplayId`` の URI・生 ID・短縮ルールの検証。
//

import XCTest

@testable import Karaoke_support

final class TrackDisplayTitleTests: XCTestCase {

	func testShortenedSpotifyDisplayIdUsesCoreAfterLastColonForURI() {
		let longCore = String(repeating: "a", count: 20)
		let uri = "spotify:track:\(longCore)"
		let out = TrackDisplayTitle.shortenedSpotifyDisplayId(uri)
		XCTAssertEqual(out.count, 17)
		XCTAssertTrue(out.hasSuffix("…"))
		XCTAssertTrue(out.hasPrefix(String(repeating: "a", count: 16)))
	}

	func testShortenedSpotifyDisplayIdReturnsShortCoreUnchanged() {
		let uri = "spotify:track:shortid"
		XCTAssertEqual(TrackDisplayTitle.shortenedSpotifyDisplayId(uri), "shortid")
	}

	func testShortenedSpotifyDisplayIdRawIdWithoutColon() {
		let raw = String(repeating: "b", count: 20)
		let out = TrackDisplayTitle.shortenedSpotifyDisplayId(raw)
		XCTAssertEqual(out.count, 17)
		XCTAssertTrue(out.hasSuffix("…"))
	}

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

	func testPrimaryPrefersUserEnteredName() {
		let track = Track(userEnteredName: "表示名", spotifyTrackId: "spotify:track:ignored")
		XCTAssertEqual(TrackDisplayTitle.primary(for: track), "表示名")
	}
}
