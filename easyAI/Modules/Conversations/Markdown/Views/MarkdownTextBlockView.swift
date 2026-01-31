//
//  MarkdownTextBlockView.swift
//  EasyAI
//
//  创建于 2026
//

import UIKit
import SnapKit

final class MarkdownTextBlockView: UIView, MarkdownBlockView {
    var category: MarkdownBlockCategory { .text }
    var onOpenURL: ((URL) -> Void)? {
        didSet { label.onOpenURL = onOpenURL }
    }

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

        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        label.adjustsFontForContentSizeCategory = true
        label.isUserInteractionEnabled = true

        addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func update(block: MarkdownBlock, style: MarkdownStyle) {
        switch block.kind {
        case .paragraph(let text):
            label.attributedText = text
        case .heading(_, let text):
            label.attributedText = text
        case .code(_, let text):
            label.attributedText = text
        default:
            label.attributedText = nil
        }
    }
}
