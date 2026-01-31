//
//  ChatMessageMarkdownCell.swift
//  EasyAI
//
//  创建于 2026
//

import UIKit
import SnapKit

final class ChatMessageMarkdownCell: ChatBaseBubbleCell {
    static let reuseIdentifier = "ChatMessageMarkdownCell"
    
    private enum BubbleSizing {
        static let stackHorizontalInset: CGFloat = 24 // 12 + 12
        static let listBulletMinWidth: CGFloat = 18
        static let listBulletToTextSpacing: CGFloat = 6
        static let codeHorizontalPadding: CGFloat = 24 // 12 + 12
        static let codeHeaderButtonWidth: CGFloat = 28
        static let codeHeaderButtonsCount: CGFloat = 2
        static let codeHeaderButtonsSpacing: CGFloat = 12
        static let codeHeaderContentSpacing: CGFloat = 10
        static let codeLanguageBadgeHorizontalPadding: CGFloat = 20 // 10 + 10
        static let quoteHorizontalPadding: CGFloat = 34 // 10 + 4 + 10 + 10
        static let widthUpdateEpsilon: CGFloat = 1
        static let preferredWidthConstraintPriority: ConstraintPriority = .init(999)
    }

    private let blocksStack = UIStackView()
    private let parser: MarkdownParsing = MarkdownParser()
    private let style = MarkdownStyle.default()
    private let stackRenderer = MarkdownBlocksStackRenderer()
    private var lastRenderedSignature: (length: Int, hash: Int)?
    private var messageId: UUID?
    private var maxBubbleWidth: CGFloat = 0
    private var lastAppliedBubbleWidth: CGFloat = 0
    private var preferredBubbleWidthConstraint: Constraint?
    private var isPreferredBubbleWidthActive = false
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        messageId = nil
        maxBubbleWidth = 0
        lastAppliedBubbleWidth = 0
        lastRenderedSignature = nil
        preferredBubbleWidthConstraint?.deactivate()
        isPreferredBubbleWidthActive = false
        blocksStack.arrangedSubviews.forEach { view in
            blocksStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }
    
    func configure(with message: Message, maxBubbleWidth: CGFloat) {
        messageId = message.id
        self.maxBubbleWidth = maxBubbleWidth
        configureBase(message: message)
        
        setBubbleHidden(message.content.isEmpty)
        blocksStack.isHidden = message.content.isEmpty
        applyMarkdownText(message.content, isStreaming: message.isStreaming)
    }

    /// 流式更新：只刷新正文，避免额外的 bubble/timestamp 逻辑和布局抖动。
    func applyStreamingText(_ text: String, maxBubbleWidth: CGFloat) {
        self.maxBubbleWidth = maxBubbleWidth
        setBubbleHidden(text.isEmpty)
        blocksStack.isHidden = text.isEmpty
        applyMarkdownText(text, isStreaming: true)
    }
    
    private func setupViews() {
        blocksStack.axis = .vertical
        blocksStack.alignment = .fill
        blocksStack.distribution = .fill
        blocksStack.spacing = 0

        bubbleContentView.addSubview(blocksStack)
        blocksStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        }

        bubbleContentView.snp.makeConstraints { make in
            preferredBubbleWidthConstraint = make.width.equalTo(0)
                .priority(BubbleSizing.preferredWidthConstraintPriority)
                .constraint
        }
        preferredBubbleWidthConstraint?.deactivate()
        isPreferredBubbleWidthActive = false
    }

    private func applyMarkdownText(_ text: String, isStreaming: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastRenderedSignature = nil
            if let messageId { ChatMessageLayoutStore.shared.clear(messageId: messageId) }
            preferredBubbleWidthConstraint?.deactivate()
            isPreferredBubbleWidthActive = false
            lastAppliedBubbleWidth = 0
            blocksStack.arrangedSubviews.forEach { view in
                blocksStack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            return
        }

        let signature = (length: text.count, hash: text.hashValue)
        if lastRenderedSignature?.length == signature.length, lastRenderedSignature?.hash == signature.hash { return }
        lastRenderedSignature = signature

        let blocks = parser.parse(text, style: style)
        updatePreferredBubbleWidth(blocks: blocks, isStreaming: isStreaming)
        stackRenderer.render(
            blocks: blocks,
            in: blocksStack,
            style: style,
            onOpenURL: { url in
                guard url.scheme != nil else { return }
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        )
    }
}

private extension ChatMessageMarkdownCell {
    func updatePreferredBubbleWidth(blocks: [MarkdownBlock], isStreaming: Bool) {
        guard let messageId else { return }
        guard let preferredBubbleWidthConstraint else { return }
        guard maxBubbleWidth > 0 else { return }

        if isStreaming {
            let pinned = ChatMessageLayoutStore.shared
                .state(messageId: messageId, contentSizeCategory: traitCollection.preferredContentSizeCategory)?
                .pinnedToMaxWidth ?? false
            if pinned {
                let clampedMax = clampPreferredBubbleWidth(maxBubbleWidth, maxBubbleWidth: maxBubbleWidth)
                preferredBubbleWidthConstraint.activate()
                preferredBubbleWidthConstraint.update(offset: clampedMax)
                isPreferredBubbleWidthActive = true
                lastAppliedBubbleWidth = clampedMax
                return
            }
        } else {
            // 流式结束：允许最终一次“微调变小”，清掉 streaming 的宽度状态。
            ChatMessageLayoutStore.shared.clear(messageId: messageId)
        }

        let measured = measurePreferredBubbleWidth(blocks: blocks, maxBubbleWidth: maxBubbleWidth)
        let clamped: CGFloat
        if isStreaming {
            let streamingMax = ChatMessageLayoutStore.shared.upsertStreamingMaxPreferredWidth(
                messageId: messageId,
                contentSizeCategory: traitCollection.preferredContentSizeCategory,
                value: measured
            )
            clamped = clampPreferredBubbleWidth(min(maxBubbleWidth, streamingMax), maxBubbleWidth: maxBubbleWidth)
            if clamped >= maxBubbleWidth - BubbleSizing.widthUpdateEpsilon {
                ChatMessageLayoutStore.shared.setPinnedToMaxWidth(
                    messageId: messageId,
                    contentSizeCategory: traitCollection.preferredContentSizeCategory,
                    pinned: true
                )
            }
        } else {
            clamped = clampPreferredBubbleWidth(measured, maxBubbleWidth: maxBubbleWidth)
        }

        if !isPreferredBubbleWidthActive || abs(clamped - lastAppliedBubbleWidth) > BubbleSizing.widthUpdateEpsilon {
            preferredBubbleWidthConstraint.activate()
            preferredBubbleWidthConstraint.update(offset: clamped)
            isPreferredBubbleWidthActive = true
            lastAppliedBubbleWidth = clamped
        }
    }

    func clampPreferredBubbleWidth(_ width: CGFloat, maxBubbleWidth: CGFloat) -> CGFloat {
        let minBubbleWidth = BubbleSizing.stackHorizontalInset
        let clamped = min(maxBubbleWidth, max(minBubbleWidth, width))
        if clamped.isNaN || clamped.isInfinite { return minBubbleWidth }
        return clamped
    }

    func measurePreferredBubbleWidth(blocks: [MarkdownBlock], maxBubbleWidth: CGFloat) -> CGFloat {
        guard maxBubbleWidth > 0 else { return 0 }
        let maxStackWidth = max(0, maxBubbleWidth - BubbleSizing.stackHorizontalInset)
        let stackWidth = measurePreferredStackWidth(blocks: blocks, maxWidth: maxStackWidth)
        return min(maxBubbleWidth, stackWidth + BubbleSizing.stackHorizontalInset)
    }

    func measurePreferredStackWidth(blocks: [MarkdownBlock], maxWidth: CGFloat) -> CGFloat {
        guard maxWidth > 0 else { return 0 }
        var maxUsed: CGFloat = 0
        for block in blocks {
            maxUsed = max(maxUsed, measurePreferredBlockWidth(block: block, maxWidth: maxWidth))
            if maxUsed >= maxWidth { return maxWidth }
        }
        return min(maxWidth, maxUsed)
    }

    func measurePreferredBlockWidth(block: MarkdownBlock, maxWidth: CGFloat) -> CGFloat {
        guard maxWidth > 0 else { return 0 }

        switch block.kind {
        case .paragraph(let text):
            return measureUsedTextWidth(text, maxWidth: maxWidth)
        case .heading(_, let text):
            return measureUsedTextWidth(text, maxWidth: maxWidth)
        case .code(let language, let text):
            let innerMax = max(0, maxWidth - BubbleSizing.codeHorizontalPadding)
            let used = measureUsedTextWidth(text, maxWidth: innerMax)
            let headerContentWidth = measureCodeHeaderContentWidth(language: language)
            let contentWidth = max(used, headerContentWidth)
            return min(maxWidth, contentWidth + BubbleSizing.codeHorizontalPadding)
        case .list(let ordered, let startIndex, let items):
            return measureListWidth(ordered: ordered, startIndex: startIndex, items: items, maxWidth: maxWidth)
        case .quote(let nested):
            let innerMax = max(0, maxWidth - BubbleSizing.quoteHorizontalPadding)
            let used = measurePreferredStackWidth(blocks: nested, maxWidth: innerMax)
            return min(maxWidth, used + BubbleSizing.quoteHorizontalPadding)
        }
    }

    func measureListWidth(
        ordered: Bool,
        startIndex: UInt,
        items: [NSAttributedString],
        maxWidth: CGFloat
    ) -> CGFloat {
        guard maxWidth > 0 else { return 0 }

        var maxRowWidth: CGFloat = 0
        for idx in 0..<items.count {
            let bulletText = ordered ? "\(Int(startIndex) + idx)." : "•"
            let bulletWidth = max(BubbleSizing.listBulletMinWidth, ceil(measurePlainTextWidth(bulletText, font: style.bodyFont)))
            let labelMax = max(0, maxWidth - bulletWidth - BubbleSizing.listBulletToTextSpacing)
            let used = measureUsedTextWidth(items[idx], maxWidth: labelMax)
            let rowWidth = min(maxWidth, bulletWidth + BubbleSizing.listBulletToTextSpacing + used)
            maxRowWidth = max(maxRowWidth, rowWidth)
            if maxRowWidth >= maxWidth { return maxWidth }
        }
        return min(maxWidth, maxRowWidth)
    }

    func measureCodeHeaderContentWidth(language: String?) -> CGFloat {
        let button = BubbleSizing.codeHeaderButtonWidth
        let spacing = BubbleSizing.codeHeaderContentSpacing
        let buttons = BubbleSizing.codeHeaderButtonsCount * button
            + max(0, BubbleSizing.codeHeaderButtonsCount - 1) * BubbleSizing.codeHeaderButtonsSpacing

        let languageText = (language ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !languageText.isEmpty else { return buttons }

        let textWidth = ceil(measurePlainTextWidth(languageText.uppercased(), font: style.codeBlockHeaderFont))
        return buttons + spacing + BubbleSizing.codeLanguageBadgeHorizontalPadding + textWidth
    }

    func measurePlainTextWidth(_ text: String, font: UIFont) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        return (text as NSString).size(withAttributes: [.font: font]).width
    }

    func measureUsedTextWidth(_ attributed: NSAttributedString, maxWidth: CGFloat) -> CGFloat {
        guard maxWidth > 0, attributed.length > 0 else { return 0 }
        let rect = attributed.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let width = ceil(rect.width)
        return min(maxWidth, max(0, width))
    }
}
