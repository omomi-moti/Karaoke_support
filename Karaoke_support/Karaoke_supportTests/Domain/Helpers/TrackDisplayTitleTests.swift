//
//  TrackDisplayTitleTests.swift
//  Karaoke_supportTests
//
//  ``TrackDisplayTitle/shortenedSpotifyDisplayId`` の URI・生 ID・短縮ルールの検証。
//

import XCTest

@testable import Karaoke_support

final class TrackDisplayTitleTests: XCTestCase {

	/// 概要: Spotify URI 形式（"spotify:track:xxxxx"）でコア部分が 16 文字を超える場合、先頭 16 文字 + "…" に短縮されること
	/// 前提(Given): コロン後のコア部分が 20 文字の Spotify URI 文字列
	/// 実行(When): TrackDisplayTitle.shortenedSpotifyDisplayId(_:) を呼ぶ
	/// 検証(Then): 返却文字列の長さが 17（16+1）で、先頭 16 文字がコア文字列、末尾が "…" になる
	func testShortenedSpotifyDisplayIdUsesCoreAfterLastColonForURI() {
		let longCore = String(repeating: "a", count: 20)
		let uri = "spotify:track:\(longCore)"
		let out = TrackDisplayTitle.shortenedSpotifyDisplayId(uri)
		XCTAssertEqual(out.count, 17)
		XCTAssertTrue(out.hasSuffix("…"))
		XCTAssertTrue(out.hasPrefix(String(repeating: "a", count: 16)))
	}

	/// 概要: コア部分が 16 文字以下の Spotify URI は短縮されず、コア文字列がそのまま返ること
	/// 前提(Given): コロン後のコア部分 "shortid"（7 文字）を持つ Spotify URI
	/// 実行(When): TrackDisplayTitle.shortenedSpotifyDisplayId(_:) を呼ぶ
	/// 検証(Then): 返却値が "shortid"（変換なし）と等しい
	func testShortenedSpotifyDisplayIdReturnsShortCoreUnchanged() {
		let uri = "spotify:track:shortid"
		XCTAssertEqual(TrackDisplayTitle.shortenedSpotifyDisplayId(uri), "shortid")
	}

	/// 概要: コロンを含まない生の ID が 16 文字を超える場合、文字列全体が先頭 16 文字 + "…" に短縮されること
	/// 前提(Given): コロンを含まない 20 文字の文字列（"bbbbb..."）
	/// 実行(When): TrackDisplayTitle.shortenedSpotifyDisplayId(_:) を呼ぶ
	/// 検証(Then): 返却文字列の長さが 17 で末尾が "…" になる
	func testShortenedSpotifyDisplayIdRawIdWithoutColon() {
		let raw = String(repeating: "b", count: 20)
		let out = TrackDisplayTitle.shortenedSpotifyDisplayId(raw)
		XCTAssertEqual(out.count, 17)
		XCTAssertTrue(out.hasSuffix("…"))
	}

	/// 概要: コア部分（最後のコロン後）が空の場合、全体文字列を対象として短縮ルールが適用されること
	/// 前提(Given): 末尾が ":" で終わる URI（コアが空）で、全体が 16 文字以下の場合と超える場合の 2 ケース
	/// 実行(When): TrackDisplayTitle.shortenedSpotifyDisplayId(_:) を呼ぶ
	/// 検証(Then): 全体が 16 文字以下なら変換なし、超える場合は全体の先頭 16 文字 + "…" に短縮される
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

	/// 概要: userEnteredName と spotifyTrackId の両方を持つ Track に対して、主タイトルとして userEnteredName が優先されること
	/// 前提(Given): userEnteredName="表示名"、spotifyTrackId="spotify:track:ignored" を持つ Track
	/// 実行(When): TrackDisplayTitle.primary(for:) を呼ぶ
	/// 検証(Then): 返却値が "表示名" と一致する
	func testPrimaryPrefersUserEnteredName() {
		let track = Track(userEnteredName: "表示名", spotifyTrackId: "spotify:track:ignored")
		XCTAssertEqual(TrackDisplayTitle.primary(for: track), "表示名")
	}
}
