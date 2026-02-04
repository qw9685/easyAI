//
//  MarkdownAttributedTextBuilder.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 将 Markdown 解析结果拼接为可选中的富文本
//
//

import Foundation
import UIKit

struct MarkdownAttributedTextBuilder {
    private let parser: MarkdownParsing
    private let style: MarkdownStyle

    init(parser: MarkdownParsing = MarkdownParser(), style: MarkdownStyle = .default()) {
        self.parser = parser
        self.style = style
    }

    func build(from text: String) -> NSAttributedString {
        let blocks = parser.parse(text, style: style)
        let output = NSMutableAttributedString()
        for (index, block) in blocks.enumerated() {
            if index > 0 {
                output.append(NSAttributedString(string: "\n\n", attributes: baseAttributes()))
            }
            output.append(render(block: block))
        }
        return output
    }
}

private extension MarkdownAttributedTextBuilder {
    func render(block: MarkdownBlock) -> NSAttributedString {
        switch block.kind {
        case .paragraph(let text):
            return text
        case .heading(_, let text):
            return text
        case .code(_, let text):
            return text
        case .list(let ordered, let startIndex, let items):
            let combined = NSMutableAttributedString()
            for (idx, item) in items.enumerated() {
                if idx > 0 { combined.append(NSAttributedString(string: "\n", attributes: baseAttributes())) }
                let prefix: String
                if ordered {
                    prefix = "\(Int(startIndex) + idx). "
                } else {
                    prefix = "• "
                }
                combined.append(NSAttributedString(string: prefix, attributes: baseAttributes()))
                combined.append(item)
            }
            return combined
        case .quote(let blocks):
            let combined = NSMutableAttributedString()
            for (idx, child) in blocks.enumerated() {
                if idx > 0 { combined.append(NSAttributedString(string: "\n", attributes: baseAttributes())) }
                let rendered = render(block: child)
                let lines = rendered.string.split(separator: "\n", omittingEmptySubsequences: false)
                for (lineIndex, line) in lines.enumerated() {
                    if lineIndex > 0 { combined.append(NSAttributedString(string: "\n", attributes: baseAttributes())) }
                    combined.append(NSAttributedString(string: "> ", attributes: baseAttributes()))
                    combined.append(NSAttributedString(string: String(line), attributes: baseAttributes()))
                }
            }
            return combined
        case .table(let headers, let rows, _):
            var lines: [NSAttributedString] = []
            if !headers.isEmpty {
                lines.append(joinTableRow(headers))
            }
            for row in rows {
                lines.append(joinTableRow(row))
            }
            let combined = NSMutableAttributedString()
            for (idx, line) in lines.enumerated() {
                if idx > 0 { combined.append(NSAttributedString(string: "\n", attributes: baseAttributes())) }
                combined.append(line)
            }
            return combined
        case .thematicBreak:
            return NSAttributedString(string: "—", attributes: baseAttributes())
        case .image(let url, let altText):
            let alt = altText?.isEmpty == false ? altText! : "image"
            return NSAttributedString(string: "[\(alt)](\(url.absoluteString))", attributes: baseAttributes())
        case .html(let raw):
            return NSAttributedString(string: raw, attributes: baseAttributes())
        case .math(let latex):
            return NSAttributedString(string: "$$\(latex)$$", attributes: baseAttributes())
        }
    }

    func joinTableRow(_ cells: [NSAttributedString]) -> NSAttributedString {
        let combined = NSMutableAttributedString()
        for (idx, cell) in cells.enumerated() {
            if idx > 0 { combined.append(NSAttributedString(string: " | ", attributes: baseAttributes())) }
            combined.append(cell)
        }
        return combined
    }

    func baseAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: style.bodyFont,
            .foregroundColor: style.textColor
        ]
    }
}
