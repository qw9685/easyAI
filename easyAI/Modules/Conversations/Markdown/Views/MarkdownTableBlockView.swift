//
//  MarkdownTableBlockView.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - Markdown 表格渲染视图
//
//

import UIKit
import SnapKit

final class MarkdownTableBlockView: UIView, MarkdownBlockView {
    var category: MarkdownBlockCategory { .table }
    var onOpenURL: ((URL) -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let container = UIView()

    private let cellPadding = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
    private let minColumnWidth: CGFloat = 90
    private let maxColumnWidth: CGFloat = 320
    private let rowSpacing: CGFloat = 0
    private var contentWidthConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = rowSpacing

        addSubview(container)
        container.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        container.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentStack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            contentWidthConstraint = make.width.equalTo(0).priority(.required).constraint
        }

        scrollView.frameLayoutGuide.snp.makeConstraints { make in
            make.height.equalTo(contentStack)
            make.width.equalTo(contentStack).priority(.low)
        }
    }

    func update(block: MarkdownBlock, style: MarkdownStyle) {
        guard case let .table(headers, rows, alignments) = block.kind else { return }

        contentStack.arrangedSubviews.forEach { view in
            contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let columnCount = max(headers.count, rows.map { $0.count }.max() ?? 0)
        guard columnCount > 0 else { return }

        let columnWidths = calculateColumnWidths(
            headers: headers,
            rows: rows,
            columnCount: columnCount
        )
        let totalWidth = columnWidths.reduce(0, +)
        contentWidthConstraint?.update(offset: max(totalWidth, 1))

        if !headers.isEmpty {
            let headerRow = buildRow(
                cells: headers,
                columnWidths: columnWidths,
                alignments: alignments,
                style: style,
                isHeader: true
            )
            contentStack.addArrangedSubview(headerRow)
        }

        for row in rows {
            let rowView = buildRow(
                cells: row,
                columnWidths: columnWidths,
                alignments: alignments,
                style: style,
                isHeader: false
            )
            contentStack.addArrangedSubview(rowView)
        }
    }
}

private extension MarkdownTableBlockView {
    func calculateColumnWidths(
        headers: [NSAttributedString],
        rows: [[NSAttributedString]],
        columnCount: Int
    ) -> [CGFloat] {
        var widths = Array(repeating: minColumnWidth, count: columnCount)

        func applyWidths(from cells: [NSAttributedString]) {
            for idx in 0..<min(columnCount, cells.count) {
                let contentWidth = measureWidth(cells[idx])
                let target = min(maxColumnWidth, max(minColumnWidth, contentWidth + cellPadding.left + cellPadding.right))
                widths[idx] = max(widths[idx], target)
            }
        }

        applyWidths(from: headers)
        for row in rows {
            applyWidths(from: row)
        }

        return widths
    }

    func measureWidth(_ attributed: NSAttributedString) -> CGFloat {
        guard attributed.length > 0 else { return 0 }
        let font = effectiveFont(for: attributed) ?? UIFont.preferredFont(forTextStyle: .body)
        let plain = attributed.string
        let width = (plain as NSString).size(withAttributes: [.font: font]).width
        return ceil(width)
    }

    func effectiveFont(for attributed: NSAttributedString) -> UIFont? {
        let range = NSRange(location: 0, length: min(1, attributed.length))
        return attributed.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
    }

    func buildRow(
        cells: [NSAttributedString],
        columnWidths: [CGFloat],
        alignments: [MarkdownTableAlignment],
        style: MarkdownStyle,
        isHeader: Bool
    ) -> UIView {
        let rowStack = UIStackView()
        rowStack.axis = .horizontal
        rowStack.alignment = .fill
        rowStack.distribution = .fill
        rowStack.spacing = 0

        for idx in 0..<columnWidths.count {
            let cellText = idx < cells.count ? cells[idx] : NSAttributedString(string: "")
            let alignment = idx < alignments.count ? alignments[idx] : .left
            let cellView = buildCell(
                text: cellText,
                width: columnWidths[idx],
                alignment: alignment,
                style: style,
                isHeader: isHeader
            )
            rowStack.addArrangedSubview(cellView)
        }

        return rowStack
    }

    func buildCell(
        text: NSAttributedString,
        width: CGFloat,
        alignment: MarkdownTableAlignment,
        style: MarkdownStyle,
        isHeader: Bool
    ) -> UIView {
        let container = UIView()
        container.layer.borderColor = style.codeBlockBorderColor.cgColor
        container.layer.borderWidth = 1 / UIScreen.main.scale
        container.backgroundColor = isHeader ? style.codeBlockHeaderBackgroundColor : style.codeBlockBackgroundColor

        let label = LinkLabel()
        label.onOpenURL = onOpenURL
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.attributedText = text
        label.textAlignment = textAlignment(for: alignment)
        label.adjustsFontForContentSizeCategory = true

        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(cellPadding)
        }

        container.snp.makeConstraints { make in
            make.width.equalTo(width)
        }

        return container
    }

    func textAlignment(for alignment: MarkdownTableAlignment) -> NSTextAlignment {
        switch alignment {
        case .center:
            return .center
        case .right:
            return .right
        case .left:
            return .left
        }
    }
}
