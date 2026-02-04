//
//  ChatBaseBubbleCell.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 气泡样式基础 cell
//
//

import UIKit
import SnapKit

class ChatBaseBubbleCell: UITableViewCell {
    let bubbleView = BubbleBackgroundView()
    let bubbleContentView = UIView()
    private let timestampLabel = UILabel()

    private let defaultBubbleBackgroundPadding = UIEdgeInsets.zero
    private var bubbleBackgroundPadding: UIEdgeInsets = .zero

    private var bubbleTopConstraint: Constraint?
    private var bubbleBottomConstraint: Constraint?
    private var bubbleLeadingConstraint: Constraint?
    private var bubbleTrailingConstraint: Constraint?

    private var contentLeadingConstraint: Constraint?
    private var contentTrailingConstraint: Constraint?
    private var contentMinLeadingConstraint: Constraint?
    private var contentMinTrailingConstraint: Constraint?
    private var timestampLeadingConstraint: Constraint?
    private var timestampTrailingConstraint: Constraint?

    private(set) var isUser: Bool = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupBaseViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBaseViews()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        timestampLabel.text = nil
        timestampLabel.isHidden = true
    }

    func configureBase(role: MessageRole, timestamp: Date?, showTimestamp: Bool) {
        isUser = role == .user
        bubbleView.isUser = isUser

        if showTimestamp, let timestamp {
            timestampLabel.isHidden = false
            timestampLabel.text = Self.formatTime(timestamp)
        } else {
            timestampLabel.isHidden = true
            timestampLabel.text = nil
        }

        updateAlignment(isUser: isUser)
    }

    /// 以 `Message` 作为统一输入，默认规则：流式期间不显示时间；流式结束后显示时间。
    func configureBase(message: Message, showTimestamp: Bool? = nil) {
        configureBase(
            role: message.role,
            timestamp: message.timestamp,
            showTimestamp: showTimestamp ?? !message.isStreaming
        )
    }

    func setBubbleHidden(_ hidden: Bool) {
        bubbleView.isHidden = hidden
        bubbleContentView.isHidden = hidden
    }

    /// 控制 bubble 背景相对内容的外扩边距（默认：top/bottom=12, left/right=16）。
    /// 传入 `.zero` 可让内容“贴边”显示（如图片消息）。
    func setBubbleBackgroundPadding(_ padding: UIEdgeInsets) {
        bubbleBackgroundPadding = padding
        bubbleTopConstraint?.update(offset: -padding.top)
        bubbleBottomConstraint?.update(offset: padding.bottom)
        bubbleLeadingConstraint?.update(offset: -padding.left)
        bubbleTrailingConstraint?.update(offset: padding.right)
    }

    private func setupBaseViews() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = true

        contentView.addSubview(bubbleView)
        contentView.addSubview(bubbleContentView)
        contentView.addSubview(timestampLabel)

        timestampLabel.font = UIFont.preferredFont(forTextStyle: .caption2)
        timestampLabel.textColor = AppTheme.textTertiary
        timestampLabel.numberOfLines = 1
        timestampLabel.isHidden = true

        bubbleView.snp.makeConstraints { make in
            bubbleTopConstraint = make.top.equalTo(bubbleContentView.snp.top).offset(-bubbleBackgroundPadding.top).constraint
            bubbleBottomConstraint = make.bottom.equalTo(bubbleContentView.snp.bottom).offset(bubbleBackgroundPadding.bottom).constraint
            bubbleLeadingConstraint = make.leading.equalTo(bubbleContentView.snp.leading).offset(-bubbleBackgroundPadding.left).constraint
            bubbleTrailingConstraint = make.trailing.equalTo(bubbleContentView.snp.trailing).offset(bubbleBackgroundPadding.right).constraint
            make.width.lessThanOrEqualToSuperview().offset(-32)
        }

        bubbleContentView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.width.lessThanOrEqualToSuperview().offset(-32)
            contentLeadingConstraint = make.leading.equalToSuperview().offset(16).constraint
            contentTrailingConstraint = make.trailing.equalToSuperview().inset(16).constraint
            contentMinLeadingConstraint = make.leading.greaterThanOrEqualToSuperview().offset(16).constraint
            contentMinTrailingConstraint = make.trailing.lessThanOrEqualToSuperview().inset(16).constraint
        }

        timestampLabel.snp.makeConstraints { make in
            make.top.equalTo(bubbleView.snp.bottom).offset(4)
            make.bottom.equalToSuperview().inset(8)
            timestampLeadingConstraint = make.leading.equalTo(bubbleView.snp.leading).offset(4).constraint
            timestampTrailingConstraint = make.trailing.equalTo(bubbleView.snp.trailing).inset(4).constraint
        }

        updateAlignment(isUser: false)
        setBubbleBackgroundPadding(defaultBubbleBackgroundPadding)
    }

    private func updateAlignment(isUser: Bool) {
        if isUser {
            contentLeadingConstraint?.deactivate()
            contentMinTrailingConstraint?.deactivate()
            contentTrailingConstraint?.activate()
            contentMinLeadingConstraint?.activate()

            timestampLabel.textAlignment = .right
            timestampLeadingConstraint?.deactivate()
            timestampTrailingConstraint?.activate()
        } else {
            contentTrailingConstraint?.deactivate()
            contentMinLeadingConstraint?.deactivate()
            contentLeadingConstraint?.activate()
            contentMinTrailingConstraint?.activate()

            timestampLabel.textAlignment = .left
            timestampTrailingConstraint?.deactivate()
            timestampLeadingConstraint?.activate()
        }
    }

    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
