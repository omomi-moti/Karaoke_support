//
//  InsightTrackRowTitleTests.swift
//  Karaoke_supportTests
//
//  I-017: ランキング行の曲名表示と SelectedTrack 生成の検証。
//

import XCTest
@testable import Karaoke_support

final class InsightTrackRowTitleTests: XCTestCase {

	/// 概要: userEnteredName と spotifyTrackId の両方がある場合、表示テキストとして userEnteredName が優先されること
	/// 前提(Given): spotifyTrackId="spotify:track:abc"、userEnteredName="表示名" を両方指定
	/// 実行(When): InsightTrackRowTitle.text(spotifyTrackId:userEnteredName:) を呼ぶ
	/// 検証(Then): 戻り値が userEnteredName の値 "表示名" と一致する
	func testText_prefersUserEnteredNameOverSpotify() {
		let t = InsightTrackRowTitle.text(
			spotifyTrackId: "spotify:track:abc",
			userEnteredName: "表示名"
		)
		XCTAssertEqual(t, "表示名")
	}

	/// 概要: userEnteredName が nil の場合、spotifyTrackId がフォールバックとして表示されること
	/// 前提(Given): spotifyTrackId="spotify:track:xyz"、userEnteredName=nil
	/// 実行(When): InsightTrackRowTitle.text(spotifyTrackId:userEnteredName:) を呼ぶ
	/// 検証(Then): 戻り値が spotifyTrackId の値 "spotify:track:xyz" と一致する
	func testText_fallsBackToSpotifyWhenUserNameEmpty() {
		let t = InsightTrackRowTitle.text(
			spotifyTrackId: "spotify:track:xyz",
			userEnteredName: nil
		)
		XCTAssertEqual(t, "spotify:track:xyz")
	}

	/// 概要: spotifyTrackId と userEnteredName がともに nil の場合、"曲名未設定" が返ること
	/// 前提(Given): spotifyTrackId=nil、userEnteredName=nil
	/// 実行(When): InsightTrackRowTitle.text(spotifyTrackId:userEnteredName:) を呼ぶ
	/// 検証(Then): 戻り値が "曲名未設定" と一致する
	func testText_unknownWhenBothMissing() {
		let t = InsightTrackRowTitle.text(spotifyTrackId: nil, userEnteredName: nil)
		XCTAssertEqual(t, "曲名未設定")
	}

	/// 概要: InsightTrackCountRanking から makeSelectedTrack() を呼ぶと、userEnteredName と spotifyTrackId が正しく引き継がれること
	/// 前提(Given): userEnteredName="歌"、spotifyTrackId="s:1" を持つ InsightTrackCountRanking
	/// 実行(When): row.makeSelectedTrack() を呼ぶ
	/// 検証(Then): 返却された SelectedTrack の userEnteredName が "歌"、spotifyTrackId が "s:1" と一致する
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

	/// 概要: InsightTrackScoreRanking から makeSelectedTrack() を呼ぶと、userEnteredName と spotifyTrackId が正しく引き継がれること
	/// 前提(Given): userEnteredName="スコア側"、spotifyTrackId="s:score" を持つ InsightTrackScoreRanking
	/// 実行(When): row.makeSelectedTrack() を呼ぶ
	/// 検証(Then): 返却された SelectedTrack の userEnteredName が "スコア側"、spotifyTrackId が "s:score" と一致する
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

	/// 概要: 同一メタデータを持つ CountRanking と ScoreRanking から makeSelectedTrack() すると同値の SelectedTrack が得られること
	/// 前提(Given): 同一 trackId / spotifyTrackId / userEnteredName を持つ InsightTrackCountRanking と InsightTrackScoreRanking
	/// 実行(When): 両方の makeSelectedTrack() を呼ぶ
	/// 検証(Then): 2 つの SelectedTrack が等値（==）になる
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

	/// 概要: userEnteredName の前後に空白がある場合、トリム後の値が SelectedTrack に格納されること
	/// 前提(Given): userEnteredName="  余白  "、spotifyTrackId=nil の InsightTrackScoreRanking
	/// 実行(When): row.makeSelectedTrack() を呼ぶ
	/// 検証(Then): SelectedTrack の userEnteredName が "余白"（トリム済み）になり、spotifyTrackId は nil のまま
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

	/// 概要: userEnteredName がホワイトスペースのみかつ spotifyTrackId が nil の場合、makeSelectedTrack() が nil を返すこと
	/// 前提(Given): userEnteredName="   "（空白のみ）、spotifyTrackId=nil の InsightTrackScoreRanking
	/// 実行(When): row.makeSelectedTrack() を呼ぶ
	/// 検証(Then): 戻り値が nil（識別情報が一切ない曲は SelectedTrack を生成できない）
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

	/// 概要: userEnteredName が空白のみでも spotifyTrackId がある場合、トリム後の spotifyTrackId を使って SelectedTrack が生成されること
	/// 前提(Given): userEnteredName=" \t "（タブ含む空白のみ）、spotifyTrackId="  spotify:id  "（前後空白あり）の InsightTrackScoreRanking
	/// 実行(When): row.makeSelectedTrack() を呼ぶ
	/// 検証(Then): SelectedTrack の spotifyTrackId が "spotify:id"（トリム済み）になり、userEnteredName は nil
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
