import XCTest
@testable import easyAI

final class MessageSearchIndexRecordTests: XCTestCase {

    func testFromMessageRecordMapsSearchFields() {
        let timestamp = Date(timeIntervalSince1970: 1234)
        let record = MessageRecord(
            id: "m1",
            conversationId: "c1",
            role: MessageRole.user.rawValue,
            content: "模型 timeout",
            timestamp: timestamp,
            isStreaming: false,
            wasStreamed: false,
            mediaPayload: nil,
            turnId: nil,
            baseId: nil,
            itemId: nil,
            promptTokens: nil,
            completionTokens: nil,
            totalTokens: nil,
            latencyMs: nil,
            estimatedCostUsd: nil,
            metricsEstimated: nil,
            routingFromModelId: nil,
            routingToModelId: nil,
            routingReason: nil,
            routingMode: nil,
            routingBudgetMode: nil,
            routingTimestamp: nil
        )

        let searchRecord = MessageSearchIndexRecord.fromMessageRecord(record)

        XCTAssertEqual(searchRecord.messageId, "m1")
        XCTAssertEqual(searchRecord.conversationId, "c1")
        XCTAssertEqual(searchRecord.sortTimestamp, 1234, accuracy: 0.0001)
        XCTAssertEqual(searchRecord.content, "模型 timeout")
        XCTAssertEqual(searchRecord.contentPinyin, "mo xing timeout")
        XCTAssertEqual(searchRecord.contentPinyinJoined, "moxingtimeout")
        XCTAssertEqual(searchRecord.contentPinyinInitials, "mxt")
        XCTAssertTrue(searchRecord.isSearchable)
    }

    func testIsSearchableReturnsFalseForBlankContent() {
        let record = MessageSearchIndexRecord(
            messageId: "m2",
            conversationId: "c2",
            sortTimestamp: 100,
            content: "  \n  ",
            contentPinyin: "",
            contentPinyinJoined: "",
            contentPinyinInitials: ""
        )

        XCTAssertFalse(record.isSearchable)
    }

    func testToSearchHitRestoresTimestampAndIdentifiers() {
        let record = MessageSearchIndexRecord(
            messageId: "m3",
            conversationId: "c3",
            sortTimestamp: 4567,
            content: "hello world",
            contentPinyin: "hello world",
            contentPinyinJoined: "helloworld",
            contentPinyinInitials: "hw"
        )

        let hit = record.toSearchHit()

        XCTAssertEqual(hit.messageId, "m3")
        XCTAssertEqual(hit.conversationId, "c3")
        XCTAssertEqual(hit.content, "hello world")
        XCTAssertEqual(hit.timestamp, Date(timeIntervalSince1970: 4567))
    }
}
