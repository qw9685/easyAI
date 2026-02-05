//
//  ChatStopNoticeCell.swift
//  easyAI
//
//  Stop notice cell (UI-only, not persisted)
//

import UIKit
import SnapKit

/// Compact stop notice row for the "no text shown yet" stop case.
/// Keep it independent from ChatBaseBubbleCell to avoid inheriting bubble paddings
/// (which made the row look too tall when there's only status + time).
final class ChatStopNoticeCell: UITableViewCell {
    static let reuseIdentifier = "ChatStopNoticeCell"

    private let statusLabel = UILabel()
    private let timestampLabel = UILabel()

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
        statusLabel.text = nil
        timestampLabel.text = nil
    }

    func configure(notice: ChatStopNotice) {
        statusLabel.text = notice.text
        timestampLabel.text = Self.formatTime(notice.timestamp)
    }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        statusLabel.font = UIFont.preferredFont(forTextStyle: .caption2)
        statusLabel.textColor = AppTheme.textSecondary
        statusLabel.numberOfLines = 1

        timestampLabel.font = UIFont.preferredFont(forTextStyle: .caption2)
        timestampLabel.textColor = AppTheme.textTertiary
        timestampLabel.numberOfLines = 1

        contentView.addSubview(statusLabel)
        contentView.addSubview(timestampLabel)

        // Align to assistant bubble leading edge (bubble leading 16 + inner 4 = 20).
        statusLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.equalToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().inset(20)
        }

        timestampLabel.snp.makeConstraints { make in
            make.top.equalTo(statusLabel.snp.bottom).offset(2)
            make.leading.equalTo(statusLabel.snp.leading)
            make.trailing.lessThanOrEqualToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(8)
        }
    }

    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
