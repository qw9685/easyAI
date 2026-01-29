//
//  ChatMessageSendCell.swift
//  EasyAI
//
//  创建于 2026
//

import UIKit
import SnapKit

/// 用户发送消息（右侧气泡）
final class ChatMessageSendCell: ChatBaseBubbleCell {
    static let reuseIdentifier = "ChatMessageSendCell"
    
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
    
    func configure(text: String, timestamp: Date) {
        configureBase(role: .user, timestamp: timestamp, showTimestamp: true)
        setBubbleHidden(text.isEmpty)
        messageLabel.textColor = .white
        messageLabel.textAlignment = .right
        messageLabel.text = text
        messageLabel.isHidden = text.isEmpty
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
