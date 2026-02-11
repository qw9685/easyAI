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
import QuartzCore

final class ChatMessageMarkdownCell: ChatBaseBubbleCell {
    static let reuseIdentifier = "ChatMessageMarkdownCell"

    private let blocksStack = UIStackView()
    private let parser: MarkdownParsing = MarkdownParser()
    private let style = MarkdownStyle.default()
    private let stackRenderer = MarkdownBlocksStackRenderer()
    private var lastRenderedText: String?
    private var fullWidthConstraint: Constraint?
    private var renderSampleCount: Int = 0

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
        lastRenderedText = nil
        blocksStack.arrangedSubviews.forEach { view in
            blocksStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }
    
    func configure(with message: Message, statusText: String?) {
        configureBase(message: message, statusText: statusText)
        
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

        bubbleContentView.snp.makeConstraints { make in
            fullWidthConstraint = make.width.equalToSuperview().offset(-32).constraint
        }
    }

    private func applyMarkdownText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastRenderedText = nil
            blocksStack.arrangedSubviews.forEach { view in
                blocksStack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            return
        }

        if lastRenderedText == text { return }
        lastRenderedText = text

        let parseStart = CACurrentMediaTime()
        let blocks = parser.parse(text, style: style)
        let parseMs = (CACurrentMediaTime() - parseStart) * 1000

        let renderStart = CACurrentMediaTime()
        stackRenderer.render(
            blocks: blocks,
            in: blocksStack,
            style: style,
            onOpenURL: { url in
                guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
                    return
                }
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        )
        let renderMs = (CACurrentMediaTime() - renderStart) * 1000

        if AppConfig.enablephaseLogs {
            renderSampleCount += 1
            let totalMs = parseMs + renderMs
            if totalMs >= 10 || renderSampleCount == 1 || renderSampleCount % 40 == 0 {
                print(
                    "[ConversationPerf][markdown] len=\(text.count) | blocks=\(blocks.count) | parseMs=\(String(format: "%.2f", parseMs)) | renderMs=\(String(format: "%.2f", renderMs))"
                )
            }
        }
    }
}
