import XCTest
@testable import easyAI

final class ConversationSearchKitTests: XCTestCase {

    func testMakeFTSMatchQuerySupportsMultiTokenPrefix() {
        XCTAssertEqual(ConversationSearchKit.makeFTSMatchQuery("ni hao"), "ni* hao*")
        XCTAssertEqual(ConversationSearchKit.makeFTSMatchQuery("timeout error"), "timeout* error*")
    }

    func testMakeFTSMatchQueryRejectsPunctuationHeavyQuery() {
        XCTAssertNil(ConversationSearchKit.makeFTSMatchQuery("c++"))
    }

    func testMatchesPhoneticallySupportsPinyinAndInitials() {
        XCTAssertTrue(ConversationSearchKit.matchesPhonetically(text: "模型选择", query: "moxing"))
        XCTAssertTrue(ConversationSearchKit.matchesPhonetically(text: "模型选择", query: "mxxz"))
        XCTAssertTrue(ConversationSearchKit.matchesPhonetically(text: "模型选择", query: "mo xing"))
    }

    func testPhoneticMatchKindDistinguishesFullAndInitials() {
        XCTAssertEqual(ConversationSearchKit.phoneticMatchKind(text: "模型选择", query: "moxing"), .full)
        XCTAssertEqual(ConversationSearchKit.phoneticMatchKind(text: "模型选择", query: "mxxz"), .initials)
    }
}
