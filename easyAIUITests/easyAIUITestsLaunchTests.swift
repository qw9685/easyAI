//
//  easyAIUITestsLaunchTests.swift
//  easyAIUITests
//
//  创建于 2025/12/9
//  主要功能：
//  - 应用启动 UI 测试与截图基线
//
//

import XCTest

final class easyAIUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // 在这里编写应用启动后、截图之前需要执行的步骤，
        // 例如登录测试账号或在应用中导航到指定页面。

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
