//
//  SingingEmptyStateCopyTests.swift
//  Karaoke_supportTests
//
//  I-016: Empty State 文言が `docs/v1_issues.md` と一致することの検証。
//

import XCTest

@testable import Karaoke_support

final class SingingEmptyStateCopyTests: XCTestCase {

	/// 概要: 歌唱データ未登録時の Empty State ヘッドラインが仕様文書（I-016）の文言と一致すること
	/// 前提(Given): SingingEmptyStateCopy.headline は静的プロパティ
	/// 実行(When): SingingEmptyStateCopy.headline を参照する
	/// 検証(Then): 値が "まず1曲歌ってみよう！" と等しい
	func testHeadlineMatchesV1IssuesI016() {
		XCTAssertEqual(SingingEmptyStateCopy.headline, "まず1曲歌ってみよう！")
	}

	/// 概要: 手動入力ボタンのタイトルが仕様文書（I-016）の文言と一致すること
	/// 前提(Given): SingingEmptyStateCopy.manualEntryButtonTitle は静的プロパティ
	/// 実行(When): SingingEmptyStateCopy.manualEntryButtonTitle を参照する
	/// 検証(Then): 値が "手動で曲名を入力して歌う" と等しい
	func testManualEntryButtonTitleMatchesV1IssuesI016() {
		XCTAssertEqual(SingingEmptyStateCopy.manualEntryButtonTitle, "手動で曲名を入力して歌う")
	}
}
