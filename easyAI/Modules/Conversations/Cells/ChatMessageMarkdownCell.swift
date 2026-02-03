//
//  ChatMessageMarkdownCell.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - Markdown 消息渲染 cell
//
//

import UIKit
import SnapKit

final class ChatMessageMarkdownCell: ChatBaseBubbleCell {
    static let reuseIdentifier = "ChatMessageMarkdownCell"

    private let blocksStack = UIStackView()
    private let parser: MarkdownParsing = MarkdownParser()
    private let style = MarkdownStyle.default()
    private let stackRenderer = MarkdownBlocksStackRenderer()
    private var lastRenderedSignature: (length: Int, hash: Int)?

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
        lastRenderedSignature = nil
        blocksStack.arrangedSubviews.forEach { view in
            blocksStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }
    
    func configure(with message: Message) {
        configureBase(message: message)
        
        setBubbleHidden(message.content.isEmpty)
        blocksStack.isHidden = message.content.isEmpty
        applyMarkdownText(message.content)
    }

    /// 流式更新：只刷新正文，避免额外的 bubble/timestamp 逻辑和布局抖动。
    func applyStreamingText(_ text: String) {
        setBubbleHidden(text.isEmpty)
        blocksStack.isHidden = text.isEmpty
        applyMarkdownText(text)
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
    }

    private func applyMarkdownText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastRenderedSignature = nil
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
