//
//  ConversationSearchModels.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 历史会话搜索结果模型
//

import Foundation

nonisolated struct TextHighlightRange: Equatable, Sendable {
    let start: Int
    let length: Int

    var end: Int {
        start + length
    }
}

nonisolated enum ConversationSearchMatchKind: Int, Equatable, Sendable {
    case titleExact = 1000
    case titlePrefix = 900
    case titleLiteral = 850
    case titleToken = 800
    case messageLiteral = 700
    case messageToken = 650
    case titlePhonetic = 550
    case messagePhonetic = 500
    case titleInitials = 450
    case messageInitials = 400

    var sortPriority: Int {
        rawValue
    }
}

nonisolated struct ConversationSearchMatch: Equatable, Sendable {
    let kind: ConversationSearchMatchKind
    let titleRanges: [TextHighlightRange]
    let snippet: String?
    let snippetRanges: [TextHighlightRange]

    var sortPriority: Int {
        kind.sortPriority
    }
}

nonisolated enum ConversationSearchRanking {
    static func sort(
        conversations: [ConversationRecord],
        matches: [String: ConversationSearchMatch]
    ) -> [ConversationRecord] {
        let originalOrder = Dictionary(uniqueKeysWithValues: conversations.enumerated().map { ($1.id, $0) })

        return conversations
            .filter { matches[$0.id] != nil }
            .sorted { lhs, rhs in
                guard let lhsMatch = matches[lhs.id],
                      let rhsMatch = matches[rhs.id] else {
                    return false
                }

                if lhsMatch.sortPriority != rhsMatch.sortPriority {
                    return lhsMatch.sortPriority > rhsMatch.sortPriority
                }

                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }

                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }

                return (originalOrder[lhs.id] ?? 0) < (originalOrder[rhs.id] ?? 0)
            }
    }
}
