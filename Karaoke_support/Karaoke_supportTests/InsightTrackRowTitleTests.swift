//
//  InsightTrackRowTitleTests.swift
//  Karaoke_supportTests
//
//  I-017: ランキング行の曲名表示と SelectedTrack 生成の検証。
//

import XCTest
@testable import Karaoke_support

final class InsightTrackRowTitleTests: XCTestCase {
	func testText_prefersUserEnteredNameOverSpotify() {
		let t = InsightTrackRowTitle.text(
			spotifyTrackId: "spotify:track:abc",
			userEnteredName: "表示名"
		)
		XCTAssertEqual(t, "表示名")
	}

	func testText_fallsBackToSpotifyWhenUserNameEmpty() {
		let t = InsightTrackRowTitle.text(
			spotifyTrackId: "spotify:track:xyz",
			userEnteredName: nil
		)
		XCTAssertEqual(t, "spotify:track:xyz")
	}

	func testText_unknownWhenBothMissing() {
		let t = InsightTrackRowTitle.text(spotifyTrackId: nil, userEnteredName: nil)
		XCTAssertEqual(t, "曲名未設定")
	}

	func testMakeSelectedTrack_fromCountRanking() {
		let id = UUID()
		let row = InsightTrackCountRanking(
			id: id,
			trackId: id,
			spotifyTrackId: "s:1",
			userEnteredName: "歌",
			countInPeriod: 3
		)
		let selected = row.makeSelectedTrack()
		XCTAssertEqual(selected?.userEnteredName, "歌")
		XCTAssertEqual(selected?.spotifyTrackId, "s:1")
	}
}
