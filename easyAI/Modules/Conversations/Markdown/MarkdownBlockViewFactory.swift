//
//  MarkdownBlockViewFactory.swift
//  EasyAI
//
//  创建于 2026
//

import UIKit

protocol MarkdownBlockViewMaking {
    func makeView(for block: MarkdownBlock) -> (UIView & MarkdownBlockView)
}

struct MarkdownBlockViewFactory: MarkdownBlockViewMaking {
    func makeView(for block: MarkdownBlock) -> (UIView & MarkdownBlockView) {
        switch block.category {
        case .text:
            return MarkdownTextBlockView()
        case .code:
            return MarkdownCodeBlockView()
        case .list:
            return MarkdownListBlockView()
        case .quote:
            return MarkdownQuoteBlockView(viewFactory: self)
        }
    }
}
