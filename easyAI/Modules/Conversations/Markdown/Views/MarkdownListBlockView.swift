//
//  MarkdownListBlockView.swift
//  EasyAI
//
//  创建于 2026
//

import UIKit
import SnapKit

final class MarkdownListBlockView: UIView, MarkdownBlockView {
    var category: MarkdownBlockCategory { .list }
    var onOpenURL: ((URL) -> Void)?

    private let stack = UIStackView()

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
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 0
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func update(block: MarkdownBlock, style: MarkdownStyle) {
        guard case let .list(ordered, startIndex, items) = block.kind else { return }

        // Remove extra views.
        while stack.arrangedSubviews.count > items.count {
            guard let v = stack.arrangedSubviews.last else { break }
            stack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }

        for idx in 0..<items.count {
            let row: MarkdownListRowView
            if idx < stack.arrangedSubviews.count, let existing = stack.arrangedSubviews[idx] as? MarkdownListRowView {
                row = existing
            } else {
                row = MarkdownListRowView()
                stack.addArrangedSubview(row)
            }
            row.onOpenURL = onOpenURL
            row.update(
                itemIndex: idx,
                ordered: ordered,
                startIndex: startIndex,
                text: items[idx],
                style: style
            )
        }
    }
}

private final class MarkdownListRowView: UIView {
    var onOpenURL: ((URL) -> Void)? {
        didSet { label.onOpenURL = onOpenURL }
    }

    private let bulletLabel = UILabel()
    private let label = LinkLabel()

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

        bulletLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        bulletLabel.setContentHuggingPriority(.required, for: .horizontal)
        bulletLabel.numberOfLines = 1

        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        label.adjustsFontForContentSizeCategory = true

        addSubview(bulletLabel)
        addSubview(label)
        bulletLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.width.greaterThanOrEqualTo(18)
        }

        label.snp.makeConstraints { make in
            make.leading.equalTo(bulletLabel.snp.trailing).offset(6)
            make.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview()
        }
    }

    func update(itemIndex: Int, ordered: Bool, startIndex: UInt, text: NSAttributedString, style: MarkdownStyle) {
        bulletLabel.font = style.bodyFont
        bulletLabel.textColor = style.secondaryTextColor
        if ordered {
            bulletLabel.text = "\(Int(startIndex) + itemIndex)."
        } else {
            bulletLabel.text = "•"
        }

        label.attributedText = text
    }
}
