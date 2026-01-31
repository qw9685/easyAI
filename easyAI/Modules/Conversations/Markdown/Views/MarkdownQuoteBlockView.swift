//
//  MarkdownQuoteBlockView.swift
//  EasyAI
//
//  创建于 2026
//

import UIKit
import SnapKit

final class MarkdownQuoteBlockView: UIView, MarkdownBlockView {
    var category: MarkdownBlockCategory { .quote }
    var onOpenURL: ((URL) -> Void)?

    private let barView = UIView()
    private let container = UIView()
    private let stack = UIStackView()
    private let stackRenderer: MarkdownBlocksStackRenderer

    init(viewFactory: MarkdownBlockViewMaking) {
        self.stackRenderer = MarkdownBlocksStackRenderer(viewFactory: viewFactory)
        super.init(frame: .zero)
        setup()
    }

    override init(frame: CGRect) {
        self.stackRenderer = MarkdownBlocksStackRenderer()
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        self.stackRenderer = MarkdownBlocksStackRenderer()
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear

        container.layer.cornerRadius = 10
        container.layer.masksToBounds = true

        barView.layer.cornerRadius = 2
        barView.layer.masksToBounds = true

        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 0

        addSubview(container)
        container.addSubview(barView)
        container.addSubview(stack)

        container.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        barView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().inset(10)
            make.width.equalTo(4)
        }

        stack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalTo(barView.snp.trailing).offset(10)
            make.trailing.equalToSuperview().inset(10)
            make.bottom.equalToSuperview().inset(10)
        }
    }

    func update(block: MarkdownBlock, style: MarkdownStyle) {
        guard case let .quote(blocks) = block.kind else { return }

        container.backgroundColor = style.quoteBackgroundColor
        barView.backgroundColor = style.quoteBarColor

        stackRenderer.render(blocks: blocks, in: stack, style: style, onOpenURL: onOpenURL)
    }
}
