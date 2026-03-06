//
//  ConversationSearchModels.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 历史会话搜索结果模型
//

import Foundation

struct TextHighlightRange: Equatable {
    let start: Int
    let length: Int

    var end: Int {
        start + length
    }
}

struct ConversationSearchMatch: Equatable {
    let titleRanges: [TextHighlightRange]
    let snippet: String?
    let snippetRanges: [TextHighlightRange]
}


