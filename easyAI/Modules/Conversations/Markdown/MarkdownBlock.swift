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
}

enum MarkdownBlockKind {
    case paragraph(text: NSAttributedString)
    case heading(level: Int, text: NSAttributedString)
    case list(ordered: Bool, startIndex: UInt, items: [NSAttributedString])
    case quote(blocks: [MarkdownBlock])
    case code(language: String?, text: NSAttributedString)
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
        }
    }
}

