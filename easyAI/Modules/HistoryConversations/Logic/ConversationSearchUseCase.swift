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

extension MessageRepository: ConversationMessageSearchProviding {}

final class ConversationSearchUseCase {
    private let messageSearchProvider: ConversationMessageSearchProviding
    private let snippetContextLength: Int
    private let snippetDefaultLength: Int
    private let snippetBoundaryScanLength: Int

    init(
        messageSearchProvider: ConversationMessageSearchProviding,
        snippetContextLength: Int = 24,
        snippetDefaultLength: Int = 56,
        snippetBoundaryScanLength: Int = 12
    ) {
        self.messageSearchProvider = messageSearchProvider
        self.snippetContextLength = snippetContextLength
        self.snippetDefaultLength = snippetDefaultLength
        self.snippetBoundaryScanLength = snippetBoundaryScanLength
    }

    func searchTitleMatches(
        query: String,
        conversations: [ConversationRecord]
    ) -> [String: ConversationSearchMatch] {
        let trimmedQuery = ConversationSearchKit.trimmedQuery(query)
        guard !trimmedQuery.isEmpty, !conversations.isEmpty else {
            return [:]
        }
        return makeTitleMatches(query: trimmedQuery, conversations: conversations)
    }

    func search(
        query: String,
        conversations: [ConversationRecord]
    ) async -> [String: ConversationSearchMatch] {
        let trimmedQuery = ConversationSearchKit.trimmedQuery(query)
        guard !trimmedQuery.isEmpty, !conversations.isEmpty else {
            return [:]
        }

        var results = makeTitleMatches(query: trimmedQuery, conversations: conversations)

        if Task.isCancelled {
            return results
        }

        let titleMatchedSet = Set(results.keys)
        let remainingConversationIDs = conversations.compactMap { conversation in
            titleMatchedSet.contains(conversation.id) ? nil : conversation.id
        }

        guard !remainingConversationIDs.isEmpty else {
            return results
        }

        let messageHits = await RuntimeTools.AsyncExecutor.run { [messageSearchProvider] in
            do {
                return try messageSearchProvider.searchFirstMatchingMessages(
                    query: trimmedQuery,
                    conversationIds: remainingConversationIDs
                )
            } catch {
                RuntimeTools.AppDiagnostics.warn(
                    "ConversationSearchUseCase",
                    "Failed to search messages: \(error)"
                )
                return []
            }
        }

        if Task.isCancelled {
            return results
        }

        for hit in messageHits {
            guard results[hit.conversationId] == nil,
                  let match = makeMessageMatch(content: hit.content, query: trimmedQuery) else {
                continue
            }
            results[hit.conversationId] = match
        }

        return results
    }

    func findHighlightRanges(in text: String, query: String) -> [TextHighlightRange] {
        let trimmedQuery = ConversationSearchKit.trimmedQuery(query)
        guard !trimmedQuery.isEmpty else { return [] }

        let literalRanges = findLiteralHighlightRanges(in: text, term: trimmedQuery)
        if !literalRanges.isEmpty {
            return literalRanges
        }

        let tokenRanges = uniqueTokens(from: trimmedQuery)
            .flatMap { findLiteralHighlightRanges(in: text, term: $0) }

        return mergeHighlightRanges(tokenRanges)
    }

    func makeSnippet(
        text: String,
        matchRange: TextHighlightRange
    ) -> (snippet: String, ranges: [TextHighlightRange]) {
        makeSnippet(text: text, highlightRanges: [matchRange])
    }

    func makeSnippet(
        text: String,
        highlightRanges: [TextHighlightRange]
    ) -> (snippet: String, ranges: [TextHighlightRange]) {
        guard !text.isEmpty else {
            return ("", [])
        }

        let mergedRanges = mergeHighlightRanges(highlightRanges)
        let totalLength = text.count

        let rawStartOffset: Int
        let rawEndOffset: Int
        if let anchor = mergedRanges.first {
            rawStartOffset = max(0, anchor.start - snippetContextLength)
            rawEndOffset = min(
                totalLength,
                max(anchor.end + snippetContextLength, rawStartOffset + snippetDefaultLength)
            )
        } else {
            rawStartOffset = 0
            rawEndOffset = min(totalLength, snippetDefaultLength)
        }

        let adjustedStartOffset = adjustedSnippetStart(in: text, from: rawStartOffset)
        let adjustedEndOffset = adjustedSnippetEnd(in: text, from: rawEndOffset)

        guard let startIndex = index(in: text, offset: adjustedStartOffset),
              let endIndex = index(in: text, offset: adjustedEndOffset),
              startIndex < endIndex else {
            return (text, mergedRanges)
        }

        let body = String(text[startIndex..<endIndex])
        let prefix = adjustedStartOffset > 0 ? "…" : ""
        let suffix = adjustedEndOffset < totalLength ? "…" : ""
        let snippet = prefix + body + suffix
        let prefixLength = prefix.count

        let snippetRanges = mergedRanges.compactMap { range -> TextHighlightRange? in
            guard range.end > adjustedStartOffset,
                  range.start < adjustedEndOffset else {
                return nil
            }

            let clippedStart = max(range.start, adjustedStartOffset)
            let clippedEnd = min(range.end, adjustedEndOffset)
            let relativeStart = clippedStart - adjustedStartOffset + prefixLength
            return TextHighlightRange(start: relativeStart, length: clippedEnd - clippedStart)
        }

        return (snippet, snippetRanges)
    }

    private func makeTitleMatches(
        query: String,
        conversations: [ConversationRecord]
    ) -> [String: ConversationSearchMatch] {
        var results: [String: ConversationSearchMatch] = [:]
        for conversation in conversations {
            guard let match = makeTitleMatch(title: conversation.title, query: query) else {
                continue
            }
            results[conversation.id] = match
        }
        return results
    }

    private func makeTitleMatch(title: String, query: String) -> ConversationSearchMatch? {
        let titleRanges = findHighlightRanges(in: title, query: query)
        guard let kind = makeTitleMatchKind(title: title, query: query, titleRanges: titleRanges) else {
            return nil
        }

        return ConversationSearchMatch(
            kind: kind,
            titleRanges: titleRanges,
            snippet: nil,
            snippetRanges: []
        )
    }

    private func makeMessageMatch(content: String, query: String) -> ConversationSearchMatch? {
        let snippetRanges = findHighlightRanges(in: content, query: query)
        let literalRanges = findLiteralHighlightRanges(in: content, term: query)

        if !snippetRanges.isEmpty {
            let snippetResult = makeSnippet(text: content, highlightRanges: snippetRanges)
            let kind: ConversationSearchMatchKind = literalRanges.isEmpty ? .messageToken : .messageLiteral
            return ConversationSearchMatch(
                kind: kind,
                titleRanges: [],
                snippet: snippetResult.snippet,
                snippetRanges: snippetResult.ranges
            )
        }

        guard let phoneticKind = ConversationSearchKit.phoneticMatchKind(text: content, query: query) else {
            return nil
        }

        let snippetResult = makeSnippet(text: content, highlightRanges: [])
        return ConversationSearchMatch(
            kind: phoneticKind == .full ? .messagePhonetic : .messageInitials,
            titleRanges: [],
            snippet: snippetResult.snippet,
            snippetRanges: []
        )
    }

    private func makeTitleMatchKind(
        title: String,
        query: String,
        titleRanges: [TextHighlightRange]
    ) -> ConversationSearchMatchKind? {
        let literalRanges = findLiteralHighlightRanges(in: title, term: query)
        if !literalRanges.isEmpty {
            if normalizedSearchText(title) == normalizedSearchText(query) {
                return .titleExact
            }
            if literalRanges.contains(where: { $0.start == 0 }) {
                return .titlePrefix
            }
            return .titleLiteral
        }

        if !titleRanges.isEmpty {
            return .titleToken
        }

        switch ConversationSearchKit.phoneticMatchKind(text: title, query: query) {
        case .full:
            return .titlePhonetic
        case .initials:
            return .titleInitials
        case .none:
            return nil
        }
    }

    private func normalizedSearchText(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func uniqueTokens(from query: String) -> [String] {
        var seen: Set<String> = []
        var tokens: [String] = []

        for token in ConversationSearchKit.searchTokens(in: query) where !token.isEmpty {
            guard seen.insert(token).inserted else { continue }
            tokens.append(token)
        }

        return tokens
    }

    private func findLiteralHighlightRanges(in text: String, term: String) -> [TextHighlightRange] {
        guard !term.isEmpty else { return [] }
        var ranges: [TextHighlightRange] = []
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let range = text.range(
                of: term,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchStart..<text.endIndex,
                locale: .current
              ) {
            ranges.append(makeHighlightRange(from: range, in: text))
            searchStart = range.upperBound
        }

        return ranges
    }

    private func mergeHighlightRanges(_ ranges: [TextHighlightRange]) -> [TextHighlightRange] {
        guard !ranges.isEmpty else { return [] }

        let sortedRanges = ranges.sorted { lhs, rhs in
            lhs.start == rhs.start ? lhs.length < rhs.length : lhs.start < rhs.start
        }

        var merged: [TextHighlightRange] = [sortedRanges[0]]
        for range in sortedRanges.dropFirst() {
            guard var last = merged.last else { continue }
            if range.start <= last.end {
                let mergedEnd = max(last.end, range.end)
                last = TextHighlightRange(start: last.start, length: mergedEnd - last.start)
                merged[merged.count - 1] = last
            } else {
                merged.append(range)
            }
        }

        return merged
    }

    private func adjustedSnippetStart(in text: String, from offset: Int) -> Int {
        guard offset > 0 else { return 0 }

        let characters = Array(text)
        let lowerBound = max(0, offset - snippetBoundaryScanLength)
        var candidate = offset

        while candidate > lowerBound {
            if isSnippetBoundary(characters[candidate - 1]) {
                break
            }
            candidate -= 1
        }

        return candidate
    }

    private func adjustedSnippetEnd(in text: String, from offset: Int) -> Int {
        let characters = Array(text)
        guard offset < characters.count else { return characters.count }

        let upperBound = min(characters.count, offset + snippetBoundaryScanLength)
        var candidate = offset

        while candidate < upperBound {
            if isSnippetBoundary(characters[candidate]) {
                break
            }
            candidate += 1
        }

        return candidate
    }

    private func isSnippetBoundary(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            CharacterSet.whitespacesAndNewlines.contains(scalar)
                || CharacterSet.punctuationCharacters.contains(scalar)
                || CharacterSet.symbols.contains(scalar)
        }
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
