//
//  ConversationSearchUseCase.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 历史会话标题/消息搜索
//  - 生成高亮与摘要片段
//

import Foundation

protocol ConversationMessageSearchProviding {
    func searchFirstMatchingMessages(query: String, conversationIds: [String]) throws -> [ConversationMessageSearchHit]
}

final class ConversationSearchUseCase {
    private let messageSearchProvider: ConversationMessageSearchProviding
    private let snippetContextLength: Int

    init(
        messageSearchProvider: ConversationMessageSearchProviding,
        snippetContextLength: Int = 24
    ) {
        self.messageSearchProvider = messageSearchProvider
        self.snippetContextLength = snippetContextLength
    }

    func search(
        query: String,
        conversations: [ConversationRecord]
    ) async -> [String: ConversationSearchMatch] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, !conversations.isEmpty else {
            return [:]
        }

        var results: [String: ConversationSearchMatch] = [:]
        let titleMatchedConversationIDs = conversations.compactMap { conversation -> String? in
            let titleRanges = findHighlightRanges(in: conversation.title, query: trimmedQuery)
            guard !titleRanges.isEmpty else { return nil }
            results[conversation.id] = ConversationSearchMatch(
                titleRanges: titleRanges,
                snippet: nil,
                snippetRanges: []
            )
            return conversation.id
        }

        if Task.isCancelled {
            return results
        }

        let titleMatchedSet = Set(titleMatchedConversationIDs)
        let remainingConversationIDs = conversations.compactMap { conversation in
            titleMatchedSet.contains(conversation.id) ? nil : conversation.id
        }

        guard !remainingConversationIDs.isEmpty else {
            return results
        }

        let messageHits = await RuntimeTools.AsyncExecutor.run { [messageSearchProvider] in
            (try? messageSearchProvider.searchFirstMatchingMessages(
                query: trimmedQuery,
                conversationIds: remainingConversationIDs
            )) ?? []
        }

        if Task.isCancelled {
            return results
        }

        for hit in messageHits {
            guard results[hit.conversationId] == nil else { continue }
            let ranges = findHighlightRanges(in: hit.content, query: trimmedQuery)
            guard let firstRange = ranges.first else { continue }
            let snippetResult = makeSnippet(text: hit.content, matchRange: firstRange)
            results[hit.conversationId] = ConversationSearchMatch(
                titleRanges: [],
                snippet: snippetResult.snippet,
                snippetRanges: snippetResult.ranges
            )
        }

        return results
    }

    func findHighlightRanges(in text: String, query: String) -> [TextHighlightRange] {
        guard !query.isEmpty else { return [] }
        var ranges: [TextHighlightRange] = []
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let range = text.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchStart..<text.endIndex,
                locale: .current
              ) {
            ranges.append(makeHighlightRange(from: range, in: text))
            searchStart = range.upperBound
        }

        return ranges
    }

    func makeSnippet(
        text: String,
        matchRange: TextHighlightRange
    ) -> (snippet: String, ranges: [TextHighlightRange]) {
        guard let startIndex = index(in: text, offset: matchRange.start),
              let endIndex = index(in: text, offset: matchRange.end) else {
            return (text, [])
        }

        let startOffset = text.distance(from: text.startIndex, to: startIndex)
        let endOffset = text.distance(from: text.startIndex, to: endIndex)

        let snippetStartOffset = max(0, startOffset - snippetContextLength)
        let snippetEndOffset = min(text.count, endOffset + snippetContextLength)

        guard let snippetStart = index(in: text, offset: snippetStartOffset),
              let snippetEnd = index(in: text, offset: snippetEndOffset) else {
            return (text, [])
        }

        let snippet = String(text[snippetStart..<snippetEnd])
        let snippetHighlight = TextHighlightRange(
            start: startOffset - snippetStartOffset,
            length: matchRange.length
        )

        return (snippet, [snippetHighlight])
    }

    private func makeHighlightRange(
        from range: Range<String.Index>,
        in text: String
    ) -> TextHighlightRange {
        TextHighlightRange(
            start: text.distance(from: text.startIndex, to: range.lowerBound),
            length: text.distance(from: range.lowerBound, to: range.upperBound)
        )
    }

    private func index(in text: String, offset: Int) -> String.Index? {
        guard offset >= 0, offset <= text.count else { return nil }
        return text.index(text.startIndex, offsetBy: offset, limitedBy: text.endIndex)
    }
}
