//
//  MarkdownBlocksStackRenderer.swift
//  EasyAI
//
//  创建于 2026
//

import UIKit

final class MarkdownBlocksStackRenderer {
    private let viewFactory: MarkdownBlockViewMaking

    init(viewFactory: MarkdownBlockViewMaking = MarkdownBlockViewFactory()) {
        self.viewFactory = viewFactory
    }

    func render(blocks: [MarkdownBlock], in stackView: UIStackView, style: MarkdownStyle, onOpenURL: ((URL) -> Void)?) {
        // Remove extra views.
        while stackView.arrangedSubviews.count > blocks.count {
            guard let view = stackView.arrangedSubviews.last else { break }
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (idx, block) in blocks.enumerated() {
            let existing = idx < stackView.arrangedSubviews.count ? stackView.arrangedSubviews[idx] : nil

            if let existingView = existing as? (UIView & MarkdownBlockView),
               existingView.category == block.category {
                existingView.onOpenURL = onOpenURL
                existingView.update(block: block, style: style)
                continue
            }

            let newView = viewFactory.makeView(for: block)
            newView.onOpenURL = onOpenURL
            newView.update(block: block, style: style)

            if let existing {
                stackView.removeArrangedSubview(existing)
                existing.removeFromSuperview()
                stackView.insertArrangedSubview(newView, at: idx)
            } else {
                stackView.addArrangedSubview(newView)
            }
        }

        // Ensure consistent vertical spacing independent of stackView.spacing.
        for idx in 0..<blocks.count {
            guard idx < stackView.arrangedSubviews.count else { continue }
            let view = stackView.arrangedSubviews[idx]
            let nextBlock = idx + 1 < blocks.count ? blocks[idx + 1] : nil
            stackView.setCustomSpacing(style.spacingAfterBlock(blocks[idx], next: nextBlock), after: view)
        }
    }
}
