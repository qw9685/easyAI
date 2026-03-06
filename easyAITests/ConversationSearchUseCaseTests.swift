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

    func testSearchTitleMatchesReturnsImmediateTitleHitsWithoutMessageLookup() {
        let provider = MockMessageSearchProvider(hits: [
            ConversationMessageSearchHit(conversationId: "c8", messageId: "m1", content: "不会被调用", timestamp: Date())
        ])
        let useCase = ConversationSearchUseCase(messageSearchProvider: provider)
        let conversations = [
            ConversationRecord(id: "c8", title: "Timeout 排查", isPinned: false, createdAt: Date(), updatedAt: Date()),
            ConversationRecord(id: "c9", title: "其他", isPinned: false, createdAt: Date(), updatedAt: Date())
        ]

        let results = useCase.searchTitleMatches(query: "timeout", conversations: conversations)

        XCTAssertEqual(results.keys.sorted(), ["c8"])
        XCTAssertEqual(results["c8"]?.kind, .titlePrefix)
        XCTAssertEqual(results["c8"]?.titleRanges, [TextHighlightRange(start: 0, length: 7)])
        XCTAssertTrue(provider.receivedQueries.isEmpty)
    }

    func testSearchTitleMatchesReturnsEmptyForBlankQuery() {
        let provider = MockMessageSearchProvider()
        let useCase = ConversationSearchUseCase(messageSearchProvider: provider)
        let conversations = [
            ConversationRecord(id: "c10", title: "任意标题", isPinned: false, createdAt: Date(), updatedAt: Date())
        ]

        let results = useCase.searchTitleMatches(query: "   ", conversations: conversations)

        XCTAssertTrue(results.isEmpty)
        XCTAssertTrue(provider.receivedQueries.isEmpty)
    }

    func testFindHighlightRangesReturnsMultipleMatches() {
        let useCase = ConversationSearchUseCase(messageSearchProvider: MockMessageSearchProvider())

        let ranges = useCase.findHighlightRanges(in: "debug bug debug", query: "debug")

        XCTAssertEqual(
            ranges,
            [
                TextHighlightRange(start: 0, length: 5),
                TextHighlightRange(start: 10, length: 5)
            ]
        )
    }

    func testFindHighlightRangesSplitsMultiTokenQuery() {
        let useCase = ConversationSearchUseCase(messageSearchProvider: MockMessageSearchProvider())

        let ranges = useCase.findHighlightRanges(in: "timeout happened before another error", query: "timeout error")

        XCTAssertEqual(
            ranges,
            [
                TextHighlightRange(start: 0, length: 7),
                TextHighlightRange(start: 32, length: 5)
            ]
        )
    }

    func testMakeSnippetAddsEllipsisAndRelativeRanges() {
        let useCase = ConversationSearchUseCase(
            messageSearchProvider: MockMessageSearchProvider(),
            snippetContextLength: 4,
            snippetDefaultLength: 8,
            snippetBoundaryScanLength: 0
        )

        let snippet = useCase.makeSnippet(
            text: "0123456789timeoutABCDE",
            matchRange: TextHighlightRange(start: 10, length: 7)
        )

        XCTAssertEqual(snippet.snippet, "…6789timeoutABCD…")
        XCTAssertEqual(snippet.ranges, [TextHighlightRange(start: 5, length: 7)])
    }

    func testSearchTitleMatchesSupportsPinyinQuery() {
        let useCase = ConversationSearchUseCase(messageSearchProvider: MockMessageSearchProvider())
        let conversations = [
            ConversationRecord(id: "c11", title: "模型选择", isPinned: false, createdAt: Date(), updatedAt: Date())
        ]

        let results = useCase.searchTitleMatches(query: "moxing", conversations: conversations)

        XCTAssertEqual(results.keys.sorted(), ["c11"])
        XCTAssertEqual(results["c11"]?.kind, .titlePhonetic)
        XCTAssertEqual(results["c11"]?.titleRanges, [])
    }

    func testSearchReturnsSnippetForPinyinMessageMatchWithoutLiteralHighlights() async {
        let provider = MockMessageSearchProvider(hits: [
            ConversationMessageSearchHit(
                conversationId: "c12",
                messageId: "m1",
                content: "模型已经准备好了",
                timestamp: Date()
            )
        ])
        let useCase = ConversationSearchUseCase(messageSearchProvider: provider)
        let conversations = [
            ConversationRecord(id: "c12", title: "测试", isPinned: false, createdAt: Date(), updatedAt: Date())
        ]

        let results = await useCase.search(query: "moxing", conversations: conversations)

        XCTAssertEqual(results["c12"]?.kind, .messagePhonetic)
        XCTAssertEqual(results["c12"]?.snippet, "模型已经准备好了")
        XCTAssertEqual(results["c12"]?.snippetRanges, [])
    }

    func testConversationSearchRankingPrefersTitlePrefixOverMessageLiteral() {
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        let conversations = [
            ConversationRecord(id: "message", title: "其他", isPinned: false, createdAt: older, updatedAt: newer),
            ConversationRecord(id: "title", title: "Timeout 排查", isPinned: false, createdAt: older, updatedAt: older)
        ]
        let matches: [String: ConversationSearchMatch] = [
            "message": ConversationSearchMatch(
                kind: .messageLiteral,
                titleRanges: [],
                snippet: "这里记录 timeout",
                snippetRanges: [TextHighlightRange(start: 5, length: 7)]
            ),
            "title": ConversationSearchMatch(
                kind: .titlePrefix,
                titleRanges: [TextHighlightRange(start: 0, length: 7)],
                snippet: nil,
                snippetRanges: []
            )
        ]

        let ranked = ConversationSearchRanking.sort(conversations: conversations, matches: matches)

        XCTAssertEqual(ranked.map(\.id), ["title", "message"])
    }

    func testConversationSearchRankingUsesPinnedAndRecencyForSamePriority() {
        let oldest = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        let newest = Date(timeIntervalSince1970: 300)
        let conversations = [
            ConversationRecord(id: "newer", title: "timeout newer", isPinned: false, createdAt: oldest, updatedAt: newer),
            ConversationRecord(id: "pinned", title: "timeout pinned", isPinned: true, createdAt: oldest, updatedAt: oldest),
            ConversationRecord(id: "newest", title: "timeout newest", isPinned: false, createdAt: oldest, updatedAt: newest)
        ]
        let sharedMatch = ConversationSearchMatch(
            kind: .titlePrefix,
            titleRanges: [TextHighlightRange(start: 0, length: 7)],
            snippet: nil,
            snippetRanges: []
        )
        let matches: [String: ConversationSearchMatch] = [
            "newer": sharedMatch,
            "pinned": sharedMatch,
            "newest": sharedMatch
        ]

        let ranked = ConversationSearchRanking.sort(conversations: conversations, matches: matches)

        XCTAssertEqual(ranked.map(\.id), ["pinned", "newest", "newer"])
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
