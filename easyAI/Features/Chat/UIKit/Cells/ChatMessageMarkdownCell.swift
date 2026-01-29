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
    
    private let contentStack = UIStackView()
    private let messageLabel = UILabel()
    
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
        messageLabel.text = nil
    }
    
    func configure(with message: Message) {
        configureBase(
            role: message.role,
            timestamp: message.timestamp,
            showTimestamp: !message.isStreaming
        )
        
        setBubbleHidden(message.content.isEmpty)
        messageLabel.textColor = .label
        messageLabel.textAlignment = .left
        
        messageLabel.text = message.content
        messageLabel.isHidden = message.content.isEmpty
        
    }
    
    private func setupViews() {
        contentStack.axis = .vertical
        contentStack.spacing = 8
        
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byCharWrapping
        messageLabel.font = UIFont.preferredFont(forTextStyle: .body)
        messageLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        messageLabel.setContentHuggingPriority(.required, for: .horizontal)
        messageLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        contentStack.addArrangedSubview(messageLabel)
        bubbleContentView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
