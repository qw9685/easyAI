import XCTest
@testable import easyAI

final class ConversationSearchUseCaseTests: XCTestCase {

    func testSearchReturnsTitleHighlightWhenConversationTitleMatches() async {
        let useCase = ConversationSearchUseCase(messageSearchProvider: MockMessageSearchProvider())
        let conversations = [
            ConversationRecord(
                id: "c1",
                title: "Swift 调试技巧",
                isPinned: false,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]

        let results = await useCase.search(query: "调试", conversations: conversations)

        XCTAssertEqual(results["c1"]?.titleRanges, [TextHighlightRange(start: 6, length: 2)])
        XCTAssertNil(results["c1"]?.snippet)
    }

    func testSearchReturnsSnippetWhenMessageMatches() async {
        let provider = MockMessageSearchProvider(hits: [
            ConversationMessageSearchHit(
                conversationId: "c2",
                messageId: "m1",
                content: "这里记录一个 networking timeout 的排查过程",
                timestamp: Date()
            )
        ])
        let useCase = ConversationSearchUseCase(messageSearchProvider: provider)
        let conversations = [
            ConversationRecord(
                id: "c2",
                title: "网络问题",
                isPinned: false,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]

        let results = await useCase.search(query: "timeout", conversations: conversations)

        XCTAssertEqual(results["c2"]?.titleRanges, [])
        XCTAssertEqual(results["c2"]?.snippet, "这里记录一个 networking timeout 的排查过程")
        XCTAssertEqual(results["c2"]?.snippetRanges, [TextHighlightRange(start: 18, length: 7)])
    }

    func testSearchOnlyUsesFirstMessageHitPerConversation() async {
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        let provider = MockMessageSearchProvider(hits: [
            ConversationMessageSearchHit(conversationId: "c3", messageId: "m2", content: "第二条 bug 记录", timestamp: newer),
            ConversationMessageSearchHit(conversationId: "c3", messageId: "m1", content: "第一条 bug 记录", timestamp: older)
        ])
        let useCase = ConversationSearchUseCase(messageSearchProvider: provider)
        let conversations = [
            ConversationRecord(id: "c3", title: "排查", isPinned: false, createdAt: older, updatedAt: newer)
        ]

        let results = await useCase.search(query: "bug", conversations: conversations)

        XCTAssertEqual(results["c3"]?.snippet, "第二条 bug 记录")
    }

    func testSearchReturnsEmptyForBlankQuery() async {
        let provider = MockMessageSearchProvider(hits: [
            ConversationMessageSearchHit(conversationId: "c4", messageId: "m1", content: "hello", timestamp: Date())
        ])
        let useCase = ConversationSearchUseCase(messageSearchProvider: provider)
        let conversations = [
            ConversationRecord(id: "c4", title: "Hello", isPinned: false, createdAt: Date(), updatedAt: Date())
        ]

        let results = await useCase.search(query: "   ", conversations: conversations)

        XCTAssertTrue(results.isEmpty)
        XCTAssertTrue(provider.receivedQueries.isEmpty)
    }

    func testSearchIsCaseInsensitive() async {
        let provider = MockMessageSearchProvider(hits: [
            ConversationMessageSearchHit(conversationId: "c5", messageId: "m1", content: "Need Fix For Timeout Error", timestamp: Date())
        ])
        let useCase = ConversationSearchUseCase(messageSearchProvider: provider)
        let conversations = [
            ConversationRecord(id: "c5", title: "Case Test", isPinned: false, createdAt: Date(), updatedAt: Date())
        ]

        let results = await useCase.search(query: "timeout", conversations: conversations)

        XCTAssertEqual(results["c5"]?.snippetRanges, [TextHighlightRange(start: 13, length: 7)])
    }

    func testSearchSkipsMessageLookupForTitleHits() async {
        let provider = MockMessageSearchProvider(hits: [
            ConversationMessageSearchHit(conversationId: "c6", messageId: "m1", content: "不会被用到", timestamp: Date())
        ])
        let useCase = ConversationSearchUseCase(messageSearchProvider: provider)
        let conversations = [
            ConversationRecord(id: "c6", title: "模型选择", isPinned: false, createdAt: Date(), updatedAt: Date()),
            ConversationRecord(id: "c7", title: "其他话题", isPinned: false, createdAt: Date(), updatedAt: Date())
        ]

        _ = await useCase.search(query: "模型", conversations: conversations)

        XCTAssertEqual(provider.receivedConversationIDs.first, ["c7"])
    }
}

private final class MockMessageSearchProvider: ConversationMessageSearchProviding {
    private let hits: [ConversationMessageSearchHit]
    private(set) var receivedQueries: [String] = []
    private(set) var receivedConversationIDs: [[String]] = []

    init(hits: [ConversationMessageSearchHit] = []) {
        self.hits = hits
    }

    func searchFirstMatchingMessages(query: String, conversationIds: [String]) throws -> [ConversationMessageSearchHit] {
        receivedQueries.append(query)
        receivedConversationIDs.append(conversationIds)
        let allowedIDs = Set(conversationIds)
        return hits.filter { allowedIDs.contains($0.conversationId) }
    }
}
