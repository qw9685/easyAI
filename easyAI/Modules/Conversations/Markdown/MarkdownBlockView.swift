//
//  MarkdownBlockView.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - Markdown 块视图协议/基类
//
//

import UIKit

protocol MarkdownBlockView where Self: UIView {
    var category: MarkdownBlockCategory { get }
    var onOpenURL: ((URL) -> Void)? { get set }
    func update(block: MarkdownBlock, style: MarkdownStyle)
}

