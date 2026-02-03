//
//  easyAIUITests.swift
//  easyAIUITests
//
//  创建于 2025/12/9
//  主要功能：
//  - UI 测试示例与启动性能测试
//
//

import XCTest

final class easyAIUITests: XCTestCase {

    override func setUpWithError() throws {
        // 在这里编写初始化代码。此方法会在每个测试方法执行前调用。

        // 在 UI 测试中，通常在发生失败时应立即停止。
        continueAfterFailure = false

        // 在 UI 测试中，运行前需要设置初始状态（如界面方向），setUp 方法适合做这些准备。
    }

    override func tearDownWithError() throws {
        // 在这里编写清理代码。此方法会在每个测试方法执行后调用。
    }

    @MainActor
    func testExample() throws {
        // UI 测试必须启动被测应用。
        let app = XCUIApplication()
        app.launch()

        // 使用 XCTAssert 等断言方法验证测试结果。
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
