//
//  ChatMessageCell.swift
//  EasyAI
//
//  创建于 2026
//

import UIKit
import SnapKit

final class ChatMessageCell: UITableViewCell {
    static let reuseIdentifier = "ChatMessageCell"
    
    private let bubbleView = BubbleBackgroundView()
    private let contentStack = UIStackView()
    private let mediaStack = UIStackView()
    private let messageLabel = UILabel()
    private let timestampLabel = UILabel()
    
    private var stackLeadingConstraint: Constraint?
    private var stackTrailingConstraint: Constraint?
    private var stackMinLeadingConstraint: Constraint?
    private var stackMinTrailingConstraint: Constraint?
    private var timestampLeadingConstraint: Constraint?
    private var timestampTrailingConstraint: Constraint?
    
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
        mediaStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        messageLabel.text = nil
        timestampLabel.text = nil
    }
    
    func configure(with message: Message) {
        let isUser = message.role == .user
        bubbleView.isUser = isUser
        messageLabel.textColor = isUser ? .white : .label
        messageLabel.textAlignment = isUser ? .right : .left
        
        mediaStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        mediaStack.isHidden = message.mediaContents.isEmpty
        if !message.mediaContents.isEmpty {
            configureMedia(message.mediaContents, isUser: isUser)
        }
        
        messageLabel.text = message.content
        messageLabel.isHidden = message.content.isEmpty
        
        if isUser || !message.isStreaming {
            timestampLabel.isHidden = false
            timestampLabel.text = Self.formatTime(message.timestamp)
        } else {
            timestampLabel.isHidden = true
        }
        
        updateAlignment(isUser: isUser)
    }
    
    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = true
        
        contentView.addSubview(bubbleView)
        contentView.addSubview(contentStack)
 
        contentStack.axis = .vertical
        contentStack.spacing = 8
        
        mediaStack.axis = .vertical
        mediaStack.spacing = 8
        contentStack.addArrangedSubview(mediaStack)
        
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byCharWrapping
        messageLabel.font = UIFont.preferredFont(forTextStyle: .body)
        messageLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        messageLabel.setContentHuggingPriority(.required, for: .horizontal)
        messageLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        contentStack.addArrangedSubview(messageLabel)
        
        timestampLabel.font = UIFont.preferredFont(forTextStyle: .caption2)
        timestampLabel.textColor = .secondaryLabel
        contentView.addSubview(timestampLabel)
        
        bubbleView.snp.makeConstraints { make in
            make.top.equalTo(contentStack.snp.top).offset(-12)
            make.bottom.equalTo(contentStack.snp.bottom).offset(12)
            make.leading.equalTo(contentStack.snp.leading).offset(-16)
            make.trailing.equalTo(contentStack.snp.trailing).offset(16)
            make.width.lessThanOrEqualToSuperview().offset(-32)
        }
        contentStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20) // bubble top(8) + padding(12)
            make.width.lessThanOrEqualToSuperview().offset(-64) // max bubble width - horizontal padding(32)
            stackLeadingConstraint = make.leading.equalToSuperview().offset(32).constraint
            stackTrailingConstraint = make.trailing.equalToSuperview().inset(32).constraint
            stackMinLeadingConstraint = make.leading.greaterThanOrEqualToSuperview().offset(32).constraint
            stackMinTrailingConstraint = make.trailing.lessThanOrEqualToSuperview().inset(32).constraint
        }
        timestampLabel.snp.makeConstraints { make in
            make.top.equalTo(bubbleView.snp.bottom).offset(4)
            make.bottom.equalToSuperview().inset(8)
            timestampLeadingConstraint = make.leading.equalTo(bubbleView.snp.leading).offset(4).constraint
            timestampTrailingConstraint = make.trailing.equalTo(bubbleView.snp.trailing).inset(4).constraint
        }

        updateAlignment(isUser: false)
    }
    
    private func updateAlignment(isUser: Bool) {
        if isUser {
            stackLeadingConstraint?.deactivate()
            stackMinTrailingConstraint?.deactivate()
            stackTrailingConstraint?.activate()
            stackMinLeadingConstraint?.activate()
            
            timestampLeadingConstraint?.deactivate()
            timestampTrailingConstraint?.activate()
        } else {
            stackTrailingConstraint?.deactivate()
            stackMinLeadingConstraint?.deactivate()
            stackLeadingConstraint?.activate()
            stackMinTrailingConstraint?.activate()
            
            timestampTrailingConstraint?.deactivate()
            timestampLeadingConstraint?.activate()
        }
    }
    
    private func configureMedia(_ mediaContents: [MediaContent], isUser: Bool) {
        for media in mediaContents {
            if media.type == .image, let uiImage = UIImage(data: media.data) {
                let imageView = UIImageView(image: uiImage)
                imageView.contentMode = .scaleAspectFit
                imageView.layer.cornerRadius = 12
                imageView.layer.masksToBounds = true
                let container = UIView()
                container.addSubview(imageView)
                imageView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                    make.width.lessThanOrEqualTo(200)
                    make.height.lessThanOrEqualTo(200)
                }
                
                mediaStack.addArrangedSubview(container)
            } else {
                let placeholder = UILabel()
                placeholder.numberOfLines = 0
                placeholder.font = UIFont.preferredFont(forTextStyle: .caption1)
                placeholder.textColor = isUser ? UIColor.white.withAlphaComponent(0.8) : .secondaryLabel
                placeholder.textAlignment = isUser ? .right : .left
                placeholder.text = "\(media.type.rawValue.uppercased()) • \(media.fileSizeFormatted)"
                mediaStack.addArrangedSubview(placeholder)
            }
        }
    }
    
    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
