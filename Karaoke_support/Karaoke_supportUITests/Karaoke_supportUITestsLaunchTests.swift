//
//  Karaoke_supportUITestsLaunchTests.swift
//  Karaoke_supportUITests
//
//  Created by 鈴木聖也 on 2026/03/14.
//

import XCTest

final class Karaoke_supportUITestsLaunchTests: XCTestCase {

    /// `true` のままだと、スキームに UI テスト用の「複数 UI 設定」が無い場合に **0 テスト扱い**になることがある（Xcode の挙動）。
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 概要: アプリが起動してフォアグラウンドに遷移することを確認するスモークテスト
    /// 前提(Given): KARAOKE_UITEST_IN_MEMORY=1 環境変数を設定した XCUIApplication
    /// 実行(When): app.launch() でアプリを起動し、.runningForeground になるまで最大 10 秒待機する
    /// 検証(Then): アプリが .runningForeground 状態になり、起動直後のスクリーンショットが添付される
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["KARAOKE_UITEST_IN_MEMORY"] = "1"
        app.launch()

        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 10),
            "アプリがフォアグラウンドになるまで待てなかった"
        )

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
