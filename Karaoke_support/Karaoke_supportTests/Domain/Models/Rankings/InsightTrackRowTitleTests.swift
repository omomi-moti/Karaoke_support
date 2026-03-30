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

	func testMakeSelectedTrack_fromScoreRanking() {
		let id = UUID()
		let row = InsightTrackScoreRanking(
			id: id,
			trackId: id,
			spotifyTrackId: "s:score",
			userEnteredName: "スコア側",
			bestScore: 92.5
		)
		let selected = row.makeSelectedTrack()
		XCTAssertEqual(selected?.userEnteredName, "スコア側")
		XCTAssertEqual(selected?.spotifyTrackId, "s:score")
	}

	func testMakeSelectedTrack_countAndScoreProduceSameSelectedTrackWhenMetadataMatches() {
		let id = UUID()
		let countRow = InsightTrackCountRanking(
			id: id,
			trackId: id,
			spotifyTrackId: "s:pair",
			userEnteredName: "同じ",
			countInPeriod: 5
		)
		let scoreRow = InsightTrackScoreRanking(
			id: id,
			trackId: id,
			spotifyTrackId: "s:pair",
			userEnteredName: "同じ",
			bestScore: 88
		)
		XCTAssertEqual(countRow.makeSelectedTrack(), scoreRow.makeSelectedTrack())
	}

	func testMakeSelectedTrack_fromScoreRanking_trimsWhitespaceOnUserEnteredName() {
		let id = UUID()
		let row = InsightTrackScoreRanking(
			id: id,
			trackId: id,
			spotifyTrackId: nil,
			userEnteredName: "  余白  ",
			bestScore: 70
		)
		let selected = row.makeSelectedTrack()
		XCTAssertEqual(selected?.userEnteredName, "余白")
		XCTAssertNil(selected?.spotifyTrackId)
	}

	func testMakeSelectedTrack_fromScoreRanking_returnsNilWhenBothIdentifiersEmptyAfterTrim() {
		let id = UUID()
		let row = InsightTrackScoreRanking(
			id: id,
			trackId: id,
			spotifyTrackId: nil,
			userEnteredName: "   ",
			bestScore: 0
		)
		XCTAssertNil(row.makeSelectedTrack())
	}

	func testMakeSelectedTrack_fromScoreRanking_whitespaceOnlyUserFallsBackToSpotifyId() {
		let id = UUID()
		let row = InsightTrackScoreRanking(
			id: id,
			trackId: id,
			spotifyTrackId: "  spotify:id  ",
			userEnteredName: " \t ",
			bestScore: 50
		)
		let selected = row.makeSelectedTrack()
		XCTAssertEqual(selected?.spotifyTrackId, "spotify:id")
		XCTAssertNil(selected?.userEnteredName)
	}
}
