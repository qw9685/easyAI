//
//  MarkdownBlock.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - Markdown 块模型定义
//
//

import Foundation

enum MarkdownBlockCategory {
    case text
    case list
    case quote
    case code
    case divider
    case table
}

enum MarkdownBlockKind {
    case paragraph(text: NSAttributedString)
    case heading(level: Int, text: NSAttributedString)
    case list(ordered: Bool, startIndex: UInt, items: [NSAttributedString])
    case quote(blocks: [MarkdownBlock])
    case code(language: String?, text: NSAttributedString)
    case thematicBreak
    case table(headers: [NSAttributedString], rows: [[NSAttributedString]], alignments: [MarkdownTableAlignment])
}

struct MarkdownBlock {
    let kind: MarkdownBlockKind
    let index: Int

    var category: MarkdownBlockCategory {
        switch kind {
        case .paragraph, .heading:
            return .text
        case .list:
            return .list
        case .quote:
            return .quote
        case .code:
            return .code
        case .thematicBreak:
            return .divider
        case .table:
            return .table
        }
    }
}

enum MarkdownTableAlignment: Equatable {
    case left
    case center
    case right
}
