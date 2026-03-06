import XCTest
@testable import easyAI

final class ChatFailureKitTests: XCTestCase {

    func testClassifyAuthenticationFailedOpenRouterError() {
        let error = OpenRouterError.authenticationFailed(message: "Missing Authentication header")

        let classified = ChatFailureKit.classify(error)

        XCTAssertEqual(classified.category, .authenticationFailed)
        XCTAssertEqual(classified.statusMessage, "鉴权失败：请检查 API Key 是否正确、是否已生效，并确认账户权限正常。")
    }

    func testClassifyAuthenticationFailedFromGenericDescription() {
        let error = NSError(domain: "test", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing Authentication header"])

        let classified = ChatFailureKit.classify(error)

        XCTAssertEqual(classified.category, .authenticationFailed)
    }
}
