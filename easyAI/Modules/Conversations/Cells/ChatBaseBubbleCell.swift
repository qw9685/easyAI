//
//  ChatBaseBubbleCell.swift
//  EasyAI
//
//  创建于 2026
//

import UIKit
import SnapKit

class ChatBaseBubbleCell: UITableViewCell {
    let bubbleView = BubbleBackgroundView()
    let bubbleContentView = UIView()
    private let timestampLabel = UILabel()

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

    func setBubbleHidden(_ hidden: Bool) {
        bubbleView.isHidden = hidden
        bubbleContentView.isHidden = hidden
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
        timestampLabel.textColor = .secondaryLabel
        timestampLabel.numberOfLines = 1
        timestampLabel.isHidden = true

        bubbleView.snp.makeConstraints { make in
            make.top.equalTo(bubbleContentView.snp.top).offset(-12)
            make.bottom.equalTo(bubbleContentView.snp.bottom).offset(12)
            make.leading.equalTo(bubbleContentView.snp.leading).offset(-16)
            make.trailing.equalTo(bubbleContentView.snp.trailing).offset(16)
            make.width.lessThanOrEqualToSuperview().offset(-32)
        }

        bubbleContentView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.width.lessThanOrEqualToSuperview().offset(-64)
            contentLeadingConstraint = make.leading.equalToSuperview().offset(32).constraint
            contentTrailingConstraint = make.trailing.equalToSuperview().inset(32).constraint
            contentMinLeadingConstraint = make.leading.greaterThanOrEqualToSuperview().offset(32).constraint
            contentMinTrailingConstraint = make.trailing.lessThanOrEqualToSuperview().inset(32).constraint
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

