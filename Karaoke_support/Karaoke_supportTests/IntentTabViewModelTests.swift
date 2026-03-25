//
//  IntentTabViewModelTests.swift
//  Karaoke_supportTests
//
//  I-017: インテントタブ ViewModel のスモークテスト。
//

import XCTest
@testable import Karaoke_support

final class IntentTabViewModelTests: XCTestCase {
	@MainActor
	func testLoad_withPreviewRepositories_loadsInsightData() async {
		let vm = IntentTabViewModel(
			insightRepository: PreviewInsightRepository(),
			sessionRepository: PreviewSessionRepository()
		)
		await vm.load()
		XCTAssertTrue(vm.hasSingingData)
		XCTAssertFalse(vm.isLoading)
		XCTAssertNil(vm.loadErrorMessage)
		XCTAssertFalse(vm.timeMachineRanking.isEmpty)
		XCTAssertEqual(vm.myAnthemRankings.count, Intent.allCases.count)
	}
}
