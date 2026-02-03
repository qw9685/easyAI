//
//  MarkdownParser.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 将 Markdown 文本解析为块结构
//
//

import Foundation
import Markdown
import UIKit

protocol MarkdownParsing {
    func parse(_ text: String, style: MarkdownStyle) -> [MarkdownBlock]
}

struct MarkdownParser: MarkdownParsing {
    func parse(_ text: String, style: MarkdownStyle) -> [MarkdownBlock] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let document = Document(parsing: text)
        var index = 0
        return parseBlocks(document.children, style: style, index: &index)
    }

    private func parseBlocks(_ nodes: MarkupChildren, style: MarkdownStyle, index: inout Int) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        blocks.reserveCapacity(8)

        for node in nodes {
            if let paragraph = node as? Paragraph {
                let attributed = renderInlineContainer(paragraph, baseFont: style.bodyFont, style: style)
                appendTextBlock(.paragraph(text: attributed), to: &blocks, index: &index)
                continue
            }

            if let heading = node as? Heading {
                let attributed = renderInlineContainer(heading, baseFont: style.headingFont(level: heading.level), style: style)
                appendTextBlock(.heading(level: heading.level, text: attributed), to: &blocks, index: &index)
                continue
            }

            if let quote = node as? BlockQuote {
                let quoteIndex = index
                index += 1
                let nested = parseBlocks(quote.children, style: style, index: &index)
                if !nested.isEmpty {
                    blocks.append(MarkdownBlock(kind: .quote(blocks: nested), index: quoteIndex))
                }
                continue
            }

            if let unordered = node as? UnorderedList {
                let items = unordered.listItems.reduce(into: [NSAttributedString]()) { result, item in
                    let rendered = renderListItem(item, style: style)
                    if rendered.length > 0 {
                        result.append(rendered)
                    }
                }
                if !items.isEmpty {
                    blocks.append(MarkdownBlock(kind: .list(ordered: false, startIndex: 1, items: items), index: index))
                    index += 1
                }
                continue
            }

            if let ordered = node as? OrderedList {
                let items = ordered.listItems.reduce(into: [NSAttributedString]()) { result, item in
                    let rendered = renderListItem(item, style: style)
                    if rendered.length > 0 {
                        result.append(rendered)
                    }
                }
                if !items.isEmpty {
                    blocks.append(MarkdownBlock(kind: .list(ordered: true, startIndex: ordered.startIndex, items: items), index: index))
                    index += 1
                }
                continue
            }

            if let codeBlock = node as? CodeBlock {
                let attributed = renderCodeBlock(codeBlock, style: style)
                blocks.append(MarkdownBlock(kind: .code(language: codeBlock.language, text: attributed), index: index))
                index += 1
                continue
            }

            if let table = node as? Table {
                let alignments = table.columnAlignments.map { alignment -> MarkdownTableAlignment in
                    switch alignment {
                    case .center:
                        return .center
                    case .right:
                        return .right
                    default:
                        return .left
                    }
                }
                let headers = renderTableHeaders(table: table, style: style)
                let rows = renderTableRows(table: table, style: style)
                blocks.append(MarkdownBlock(kind: .table(headers: headers, rows: rows, alignments: alignments), index: index))
                index += 1
                continue
            }

            if node is ThematicBreak {
                blocks.append(MarkdownBlock(kind: .thematicBreak, index: index))
                index += 1
                continue
            }

            // Fallback: try to render children as paragraph.
            let attributed = renderMarkupAsInline(node, baseFont: style.bodyFont, style: style)
            appendTextBlock(.paragraph(text: attributed), to: &blocks, index: &index)
        }

        return blocks
    }

    private func renderTableHeaders(table: Table, style: MarkdownStyle) -> [NSAttributedString] {
        guard let head = table.children.compactMap({ $0 as? Table.Head }).first else { return [] }
        guard let firstRow = head.children.compactMap({ $0 as? Table.Row }).first else { return [] }
        let cells = firstRow.children.compactMap { $0 as? Table.Cell }
        return cells.map { renderTableCell($0, style: style, isHeader: true) }
    }

    private func renderTableRows(table: Table, style: MarkdownStyle) -> [[NSAttributedString]] {
        guard let body = table.children.compactMap({ $0 as? Table.Body }).first else { return [] }
        let rows = body.children.compactMap { $0 as? Table.Row }
        return rows.map { row in
            let cells = row.children.compactMap { $0 as? Table.Cell }
            return cells.map { renderTableCell($0, style: style, isHeader: false) }
        }
    }

    private func renderTableCell(_ cell: Table.Cell, style: MarkdownStyle, isHeader: Bool) -> NSAttributedString {
        let baseFont = isHeader ? style.headingFont(level: 3) : style.bodyFont
        let output = NSMutableAttributedString()
        let base = baseAttributes(style: style, font: baseFont)

        for child in cell.children {
            appendInline(child, into: output, baseFont: baseFont, style: style, attributes: base)
        }
        applyBareLinksIfNeeded(to: output, linkColor: style.linkColor)
        return output
    }

    private func appendTextBlock(_ kind: MarkdownBlockKind, to blocks: inout [MarkdownBlock], index: inout Int) {
        let attributed: NSAttributedString?
        switch kind {
        case .paragraph(let text):
            attributed = text
        case .heading(_, let text):
            attributed = text
        default:
            attributed = nil
        }

        if let attributed, attributed.length > 0 {
            blocks.append(MarkdownBlock(kind: kind, index: index))
            index += 1
        }
    }

    private func renderListItem(_ item: ListItem, style: MarkdownStyle) -> NSAttributedString {
        // ListItem contains block children; most commonly a single Paragraph.
        if item.childCount == 1, let paragraph = item.child(at: 0) as? Paragraph {
            return renderInlineContainer(paragraph, baseFont: style.bodyFont, style: style)
        }

        let joined = NSMutableAttributedString()
        for idx in 0..<item.childCount {
            guard let child = item.child(at: idx) else { continue }
            let part: NSAttributedString
            if let paragraph = child as? Paragraph {
                part = renderInlineContainer(paragraph, baseFont: style.bodyFont, style: style)
            } else if let heading = child as? Heading {
                part = renderInlineContainer(heading, baseFont: style.headingFont(level: heading.level), style: style)
            } else {
                part = renderMarkupAsInline(child, baseFont: style.bodyFont, style: style)
            }
            if part.length == 0 { continue }
            if joined.length > 0 { joined.append(NSAttributedString(string: "\n", attributes: baseAttributes(style: style, font: style.bodyFont))) }
            joined.append(part)
        }
        return joined
    }

    private func renderCodeBlock(_ block: CodeBlock, style: MarkdownStyle) -> NSAttributedString {
        let paragraphStyle = codeBlockParagraphStyle()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: style.codeBlockFont,
            .foregroundColor: style.codeBlockTextColor,
            .paragraphStyle: paragraphStyle
        ]
        let text = block.code.trimmingCharacters(in: .newlines)
        let attributed = NSMutableAttributedString(string: text, attributes: attributes)
        applyBareLinksIfNeeded(to: attributed, linkColor: style.linkColor)
        return attributed
    }

    private func renderInlineContainer(_ container: Markup, baseFont: UIFont, style: MarkdownStyle) -> NSAttributedString {
        let output = NSMutableAttributedString()
        let base = baseAttributes(style: style, font: baseFont)
        for child in container.children {
            appendInline(child, into: output, baseFont: baseFont, style: style, attributes: base)
        }
        applyBareLinksIfNeeded(to: output, linkColor: style.linkColor)
        return output
    }

    private func renderMarkupAsInline(_ markup: Markup, baseFont: UIFont, style: MarkdownStyle) -> NSAttributedString {
        let output = NSMutableAttributedString()
        let base = baseAttributes(style: style, font: baseFont)

        if markup.childCount == 0 {
            // Treat leaf nodes as plain text by using their plainText when available.
            if let plain = (markup as? PlainTextConvertibleMarkup)?.plainText, !plain.isEmpty {
                output.append(NSAttributedString(string: plain, attributes: base))
            }
            applyBareLinksIfNeeded(to: output, linkColor: style.linkColor)
            return output
        }

        for child in markup.children {
            appendInline(child, into: output, baseFont: baseFont, style: style, attributes: base)
        }
        applyBareLinksIfNeeded(to: output, linkColor: style.linkColor)
        return output
    }

    private func appendInline(
        _ markup: Markup,
        into output: NSMutableAttributedString,
        baseFont: UIFont,
        style: MarkdownStyle,
        attributes: [NSAttributedString.Key: Any]
    ) {
        if let text = markup as? Text {
            output.append(NSAttributedString(string: text.string, attributes: attributes))
            return
        }

        if markup is SoftBreak || markup is LineBreak {
            output.append(NSAttributedString(string: "\n", attributes: attributes))
            return
        }

        if let inlineCode = markup as? InlineCode {
            var attrs = attributes
            attrs[.font] = style.inlineCodeFont
            attrs[.backgroundColor] = style.inlineCodeBackgroundColor
            output.append(NSAttributedString(string: inlineCode.code, attributes: attrs))
            return
        }

        if let strong = markup as? Strong {
            var attrs = attributes
            if let font = attrs[.font] as? UIFont {
                attrs[.font] = font.withTraits(.traitBold)
            } else {
                attrs[.font] = baseFont.withTraits(.traitBold)
            }
            for child in strong.children {
                appendInline(child, into: output, baseFont: baseFont, style: style, attributes: attrs)
            }
            return
        }

        if let emphasis = markup as? Emphasis {
            var attrs = attributes
            if let font = attrs[.font] as? UIFont {
                attrs[.font] = font.withTraits(.traitItalic)
            } else {
                attrs[.font] = baseFont.withTraits(.traitItalic)
            }
            for child in emphasis.children {
                appendInline(child, into: output, baseFont: baseFont, style: style, attributes: attrs)
            }
            return
        }

        if let strike = markup as? Strikethrough {
            var attrs = attributes
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            for child in strike.children {
                appendInline(child, into: output, baseFont: baseFont, style: style, attributes: attrs)
            }
            return
        }

        if let link = markup as? Link, let destination = link.destination, let url = URL(string: destination) {
            var attrs = attributes
            attrs[.link] = url
            attrs[.foregroundColor] = style.linkColor
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            for child in link.children {
                appendInline(child, into: output, baseFont: baseFont, style: style, attributes: attrs)
            }
            return
        }

        // Default: recurse.
        for child in markup.children {
            appendInline(child, into: output, baseFont: baseFont, style: style, attributes: attributes)
        }
    }

    private func baseAttributes(style: MarkdownStyle, font: UIFont) -> [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: style.textColor,
            .paragraphStyle: baseParagraphStyle()
        ]
    }

    private func baseParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = 0
        style.paragraphSpacingBefore = 0
        style.lineBreakMode = .byCharWrapping
        return style
    }

    private func codeBlockParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = 0
        style.paragraphSpacingBefore = 0
        style.lineBreakMode = .byWordWrapping
        style.lineHeightMultiple = 1.24
        style.paragraphSpacing = 3
        return style
    }

    private func applyBareLinksIfNeeded(to attributed: NSMutableAttributedString, linkColor: UIColor) {
        let fullRange = NSRange(location: 0, length: attributed.length)
        guard fullRange.length > 0 else { return }

        let detector: NSDataDetector
        do {
            detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        } catch {
            return
        }

        let matches = detector.matches(in: attributed.string, options: [], range: fullRange)
        guard !matches.isEmpty else { return }

        var existingLinkRanges: [NSRange] = []
        attributed.enumerateAttribute(.link, in: fullRange, options: []) { value, range, _ in
            if value != nil {
                existingLinkRanges.append(range)
            }
        }

        func overlapsExistingLink(_ range: NSRange) -> Bool {
            for existing in existingLinkRanges {
                if NSIntersectionRange(existing, range).length > 0 {
                    return true
                }
            }
            return false
        }

        for match in matches {
            guard let url = match.url else { continue }
            let range = match.range
            guard range.length > 0 else { continue }
            guard !overlapsExistingLink(range) else { continue }
            attributed.addAttribute(.link, value: url, range: range)
            attributed.addAttribute(.foregroundColor, value: linkColor, range: range)
            attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
    }
}
