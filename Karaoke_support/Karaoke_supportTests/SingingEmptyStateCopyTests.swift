//
//  SingingEmptyStateCopyTests.swift
//  Karaoke_supportTests
//
//  I-016: Empty State 文言が `docs/v1_issues.md` と一致することの検証。
//

import XCTest

@testable import Karaoke_support

final class SingingEmptyStateCopyTests: XCTestCase {
	func testHeadlineMatchesV1IssuesI016() {
		XCTAssertEqual(SingingEmptyStateCopy.headline, "まず1曲歌ってみよう！")
	}

	func testManualEntryButtonTitleMatchesV1IssuesI016() {
		XCTAssertEqual(SingingEmptyStateCopy.manualEntryButtonTitle, "手動で曲名を入力して歌う")
	}
}
