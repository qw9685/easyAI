//
//  MarkdownTextBlockView.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 段落/标题文本块视图
//
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
            label.attributedText = replaceInlineMath(in: text, style: style)
        case .heading(_, let text):
            label.attributedText = replaceInlineMath(in: text, style: style)
        case .code(_, let text):
            label.attributedText = text
        default:
            label.attributedText = nil
        }
    }
}

private extension MarkdownTextBlockView {
    func replaceInlineMath(in text: NSAttributedString, style: MarkdownStyle) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: text)
        let fullRange = NSRange(location: 0, length: mutable.length)
        var rangesToReplace: [(NSRange, String)] = []

        mutable.enumerateAttribute(.link, in: fullRange, options: []) { value, range, _ in
            guard let str = value as? String, str.hasPrefix("math:") else { return }
            let latex = String(str.dropFirst(5))
            rangesToReplace.append((range, latex))
        }

        for (range, latex) in rangesToReplace.reversed() {
            let attachment = MathInlineAttachment(latex: latex, font: style.bodyFont)
            let attr = NSAttributedString(attachment: attachment)
            mutable.replaceCharacters(in: range, with: attr)
        }

        return mutable
    }
}

private final class MathInlineAttachment: NSTextAttachment {
    private let latex: String
    private let font: UIFont
    private var renderedImage: UIImage?

    init(latex: String, font: UIFont) {
        self.latex = latex
        self.font = font
        super.init(data: nil, ofType: nil)
        render()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func render() {
        let label = UILabel()
        label.font = font
        label.text = latex
        label.textColor = AppTheme.textSecondary
        label.sizeToFit()
        let size = CGSize(width: max(12, label.bounds.width + 6), height: max(12, label.bounds.height + 4))
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            label.frame = CGRect(origin: CGPoint(x: 3, y: 2), size: label.bounds.size)
            label.drawHierarchy(in: label.frame, afterScreenUpdates: true)
        }
        renderedImage = image
        self.image = image
        self.bounds = CGRect(x: 0, y: -2, width: size.width, height: size.height)
    }
}
